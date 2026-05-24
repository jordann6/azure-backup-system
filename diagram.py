from diagrams import Diagram, Cluster, Edge
from diagrams.azure.storage import StorageAccounts
from diagrams.azure.integration import LogicApps
from diagrams.azure.identity import ManagedIdentities
from diagrams.azure.general import Resourcegroups, Scheduler, CostManagement

graph_attrs = {
    "fontsize": "13",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "ortho",
}

node_attrs = {
    "fontsize": "11",
}

with Diagram(
    "Azure Automated Backup System",
    filename="docs/architecture",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attrs,
    node_attr=node_attrs,
):
    timer = Scheduler("Recurrence Trigger\nDaily 08:00 UTC")

    with Cluster("rg-backup-dev · East US"):
        logic = LogicApps("Logic App\nbackup-confirmation")
        identity = ManagedIdentities("Managed Identity\n(System Assigned)")

        with Cluster("Storage Account · stbackupdev{suffix}"):
            storage = StorageAccounts("Blob Storage\nVersioning Enabled\nSoft Delete: 7 days")
            lifecycle = CostManagement("Lifecycle Policy\nHot → Cool 30d\nCool → Archive 90d\nDelete 365d")

    timer >> Edge(label="trigger") >> logic
    logic >> Edge(label="authenticates via") >> identity
    identity >> Edge(label="RBAC: Blob Data Reader") >> storage
    logic >> Edge(label="LIST blobs (MSI auth)") >> storage
    storage - Edge(style="dashed", label="manages tiers") - lifecycle
