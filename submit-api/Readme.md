CSCS Developed go-cardano-submit-api ( https://github.com/cloudstruct/go-cardano-submit-api )

Let's see if we can use it as a replacement for IOG's version.



Build / Install Notes:

cd /usr/ports/lang/go/ && make install clean

git clone https://github.com/cloudstruct/go-cardano-submit-api.git

cd ./go-cardano-submit-api

make

The cardano-submit-api binary will be availabe in the same directory after build process is finished. Install by running:

cp cardano-submit-api /usr/local/bin/

The binary does not require arguments, however, it expects CARDANO_NODE_SOCKET_PATH ENV var to be set, or the socket file to be located at "/node-ipc/node.socket"

If you are using the cardano-node FreeBSD port, you can change cardano-node socket file location by adding the following line in the /etc/rc.conf files :
cardano_node_socket="/node-ipc/node.socket"

By default, the SubmitAPI services runs on port 8090 and the metrics endpoint is accessible at http://localhost:8081/
