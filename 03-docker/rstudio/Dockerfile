# Use the official Ubuntu 24.04 base image
FROM ubuntu:24.04

# Create the directory for the installs.

RUN  mkdir /rstudio

# Add systemctl script to enable systemctl commands in the container

COPY systemctl.py /usr/bin/systemctl
RUN chmod a+x /usr/bin/systemctl

# Install packages for RStudio and R

COPY packages.sh /rstudio
RUN  chmod +x /rstudio/packages.sh && /rstudio/packages.sh

# Install aws cli

COPY awscli.sh /rstudio
RUN  chmod +x /rstudio/awscli.sh && /rstudio/awscli.sh
        
# Expose port 8000 for the Flask application
EXPOSE 8787                                         

# Set the default command to run the Flask application
ENTRYPOINT [ "/rstudio/startup.sh" ]          
