FROM ubuntu
COPY . /app
RUN dpkg -i /app/chef_17.7.29-1_amd64.deb
RUN apt update
RUN apt install -y git
WORKDIR /app
RUN git clone https://github.com/chef-partners/azure-chef-extension.git
WORKDIR /app/azure-chef-extension
ENV azure_extension_cli=/app/azure-extensions-cli_linux_amd64 
ENV EXTENSION_NAMESPACE=Chef.Bootstrap.WindowsAzure 
ENV MANAGEMENT_URL=https://management.core.windows.net/ 
ENV SUBSCRIPTION_ID=9141ca47-b2fc-444d-8eb0-8bc58ef32f13 
ENV SUBSCRIPTION_CERT=/app/managementCertificate.pem 
ENV publishsettings=/app/opscode-azure-msdn-premium-4-3-2013-credentials.publishsettings
ENV PATH=$PATH:/opt/chef/embedded/bin
RUN $azure_extension_cli list-versions
RUN apt install -y build-essential
RUN ruby -v
RUN gem install bundler
RUN bundle install 
