# Create a cluster with 4 nodes and local SSD. The last node is used as a
# load generator for some tests. Note that the cluster name must always begin
# with your username.
export CLUSTER="${USER:0:6}-test"

# Destroy the cluster.
roachprod destroy ${CLUSTER}
