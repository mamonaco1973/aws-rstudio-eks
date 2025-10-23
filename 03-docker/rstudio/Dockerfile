# Use the official Ubuntu 24.04 base image
FROM ubuntu:24.04

# Create the directory for the installs.

RUN  mkdir /rstudio

# Install packages for RStudio and R

COPY packages.sh /rstudio
RUN  chmod +x /rstudio/packages.sh && /rstudio/packages.sh

# Install aws cli

COPY awscli.sh /rstudio
RUN  chmod +x /rstudio/awscli.sh && /rstudio/awscli.sh

# Install rstudio server

COPY rstudio.sh /rstudio
RUN  chmod +x /rstudio/rstudio.sh && /rstudio/rstudio.sh

# Create local user for RStudio server -  If the identity provider fails 
# we can still log in with this local user.

# Define environment variables
ENV USER=rstudio \
    HOME=/home/rstudio

# Create the user and home directory
RUN useradd -m -s /bin/bash ${USER} && \
    echo "${USER}:rstudio" | chpasswd && \
    adduser ${USER} sudo

# Expose port 8787 for the RStudio server
EXPOSE 8787                                         

# Set the default command to run the RStudio server
COPY startup.sh /rstudio/

# Add systemctl script to enable systemctl commands in the container

# Remove the real systemctl binary (from systemd package)

RUN rm -f /usr/bin/systemctl
COPY systemctl.py /usr/bin/systemctl
RUN chmod +x /usr/bin/systemctl

ENTRYPOINT [ "/rstudio/startup.sh" ]          
