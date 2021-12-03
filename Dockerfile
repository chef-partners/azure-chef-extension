FROM chefes/releng-base
ENV VAULT_ADDR="https://vault.es.chef.co"
ENV VAULT_NAMESPACE="releng"
ARG token
WORKDIR /workdir
COPY . /workdir
RUN git clone https://github.com/chef-partners/azure-chef-extension.git
WORKDIR /workdir/azure-chef-extension
RUN bundle install
RUN git config --global core.autocrlf false
WORKDIR /workdir
RUN chmod +x /workdir/publicenvvar.sh
CMD "/workdir/publicenvvar.sh"
