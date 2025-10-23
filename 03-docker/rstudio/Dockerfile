# Use the official Ubuntu 24.04 base image
FROM ubuntu:24.04

# Create the directory for the installs.

RUN  mkdir /rstudio

# Copy application files to the /rstudio directory in the container
COPY packages.sh /rstudio
RUN  chmod +x /rstudio/packages.sh && /rstudio/packages.sh
        
# Expose port 8000 for the Flask application
EXPOSE 8787                                         

# Set the default command to run the Flask application
ENTRYPOINT [ "/rstudio/startup.sh" ]          
