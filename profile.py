# Adapted from the small-lan profile

# Import the Portal object.
import geni.portal as portal
# Import the ProtoGENI library.
import geni.rspec.pg as pg
# Emulab specific extensions.
import geni.rspec.emulab as emulab

# Create a portal context, needed to defined parameters
pc = portal.Context()

# Create a Request object to start building the RSpec.
request = pc.makeRequestRSpec()

# Variable number of nodes.
pc.defineParameter("workerCount", "Number of k0s Worker Nodes", portal.ParameterType.INTEGER, 1,
                   longDescription="Number of worker nodes in the k0s cluster - 0 means only controller node")

# Pick your OS.
imageList = [
    ('urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU24-64-STD', 'Ubuntu 24.04'),
    ('urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD', 'Ubuntu 22.04')]

pc.defineParameter("osImage", "Select OS image",
                   portal.ParameterType.IMAGE,
                   imageList[0], imageList,
                   longDescription="Most clusters have this set of images, " +
                   "pick your favorite one.")

# Optional physical type for all nodes.
pc.defineParameter("phystype",  "Optional physical node type",
                   portal.ParameterType.NODETYPE, "",
                   longDescription="Pick a single physical node type (pc3000,d710,etc) " +
                   "instead of letting the resource mapper choose for you.")

# Optional link speed, normally the resource mapper will choose for you based on node availability
pc.defineParameter("linkSpeed", "Link Speed",portal.ParameterType.INTEGER, 0,
                   [(0,"Any"),(100000,"100Mb/s"),(1000000,"1Gb/s"),(10000000,"10Gb/s"),(25000000,"25Gb/s"),(100000000,"100Gb/s")],
                   advanced=True,
                   longDescription="A specific link speed to use for your lan. Normally the resource " +
                   "mapper will choose for you based on node availability and the optional physical type.")

# Optional ephemeral blockstore
pc.defineParameter("tempFileSystemSize", "Temporary Filesystem Size",
                   portal.ParameterType.INTEGER, 0,advanced=True,
                   longDescription="The size in GB of a temporary file system to mount on each of your " +
                   "nodes. Temporary means that they are deleted when your experiment is terminated. " +
                   "The images provided by the system have small root partitions, so use this option " +
                   "if you expect you will need more space to build your software packages or store " +
                   "temporary files.")
                   
# Instead of a size, ask for all available space. 
pc.defineParameter("tempFileSystemMax",  "Temp Filesystem Max Space",
                    portal.ParameterType.BOOLEAN, False,
                    advanced=True,
                    longDescription="Instead of specifying a size for your temporary filesystem, " +
                    "check this box to allocate all available disk space. Leave the size above as zero.")

pc.defineParameter("tempFileSystemMount", "Temporary Filesystem Mount Point",
                   portal.ParameterType.STRING,"/mydata",advanced=True,
                   longDescription="Mount the temporary file system at this mount point; in general you " +
                   "you do not need to change this, but we provide the option just in case your software " +
                   "is finicky.")

# Retrieve the values the user specifies during instantiation.
params = pc.bindParameters()

# Check parameter validity.
if params.tempFileSystemSize < 0 or params.tempFileSystemSize > 200:
    pc.reportError(portal.ParameterError("Please specify a size greater then zero and " +
                                         "less then 200GB", ["tempFileSystemSize"]))

if params.phystype != "":
    tokens = params.phystype.split(",")
    if len(tokens) != 1:
        pc.reportError(portal.ParameterError("Only a single type is allowed", ["phystype"]))

pc.verifyParameters()

# Create link/lan.
lan = request.LAN()
if params.linkSpeed > 0:
    lan.bandwidth = params.linkSpeed

# function to create a generic node for us
def create_node(name):
    # Create a node and add it to the request
    node = request.RawPC(name)
    if params.osImage and params.osImage != "default":
        node.disk_image = params.osImage
    # Add to lan
    iface = node.addInterface("eth1")
    lan.addInterface(iface)
    # Optional hardware type.
    if params.phystype != "":
        node.hardware_type = params.phystype
    # Optional Blockstore
    if params.tempFileSystemSize > 0 or params.tempFileSystemMax:
        bs = node.Blockstore(name + "-bs", params.tempFileSystemMount)
        if params.tempFileSystemMax:
            bs.size = "0GB"
        else:
            bs.size = str(params.tempFileSystemSize) + "GB"
        bs.placement = "any"
    # Ensure the SSH keys are bootstrapped
    node.addService(pg.Execute(shell="bash", command="/local/repository/bootstrap-ssh-keys.sh"))
    return node

# Process the RAN node
node = create_node("ran")
node.addService(pg.Execute(shell="bash", command="/local/repository/deploy-ran.sh"))

# Process the Core + Nomadix Controller node
node = create_node("ran")
node.addService(pg.Execute(shell="bash", command="/local/repository/deploy-core.sh"))
node.addService(pg.Execute(shell="bash", command="/local/repository/deploy-controller.sh"))

# Process the k0s controller node
node = create_node("ran")
node.addService(pg.Execute(shell="bash", command="/local/repository/install-k0s.sh " + str(params.workerCount)))

# Process k0s worker nodes
for i in range(params.workerCount):
    # Create a node and add it to the request
    node = create_node("k0s-worker-" + str(i))
    # Don't need to do anything special for the worker nodes
    # as the controller node orchestrates them

# Print the RSpec to the enclosing page.
pc.printRequestRSpec(request)
