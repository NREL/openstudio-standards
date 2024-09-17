# Using Visual Studio Code and DevContainers for Openstudio-Standards Development. 

## Requirements
### Docker
**Windows**: [Docker Desktop 2.0+](https://www.docker.com/products/docker-desktop/) on Windows 10 Pro/Enterprise. Windows 10 Home (2004+) requires Docker Desktop 2.3+ and the WSL 2 back-end. (Docker Toolbox is not supported. Windows container images are not supported.) Installation instructions are [here](https://docs.docker.com/desktop/install/windows-install/) ensure that your windows user account is part of the docker-group. Do not skip that step. 
**macOS**: [Docker Desktop 2.0+](https://www.docker.com/products/docker-desktop/).
**Linux**: Docker CE/EE 18.06+ and Docker Compose 1.21+. (The Ubuntu snap package is not supported.) Use your distros package manager to install.

Ensure that docker desktop is running on your system.  You should see it present in your windows task tray.  Then run the following command. 

```
docker hello-world
```

You should see the following output.

```
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
c1ec31eb5944: Pull complete
Digest: sha256:d000bc569937abbe195e20322a0bde6b2922d805332fd6d8a68b19f524b7d21d
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```




    * 
### Visual Studio Code
[Visual Studio Code](https://code.visualstudio.com/)
## Configuration
1. Launch vscode and install the following extenstions. 
    * [Remote-Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
    * [Remote-Containers-Extention-Pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

## Development Workflow

### Clone Repository into a DevContainer





