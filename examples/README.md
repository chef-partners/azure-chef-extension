**Following are the References to doc for Chef Extension and different Azure command line tools**

1. [Azure portal](https://docs.chef.io/azure_portal.html)
2. [Azure Powershell cmdlets](./azure-powershell-examples.md)
3. [Azure Xplat CLI](./azure-xplat-cli-examples.md)
4. [Knife Azure Plugin](./knife-azure-plugin-examples.md)

## Licensed Download Support

To use licensed Chef Infra Client downloads, set both `CHEF_LICENSE` and `chef_license_key` in your extension public settings. The handler reads `chef_license_key` and automatically exports it as `CHEF_LICENSE_KEY` before the installer runs.

```json
{
  "settings": {
    "CHEF_LICENSE": "accept-no-persist",
    "chef_license_key": "<your-chef-license-key>",
    "bootstrap_options": {
      "chef_node_name": "my-node",
      "chef_server_url": "https://chef-server/organizations/myorg",
      "validation_client_name": "myorg-validator"
    }
  }
}
```

Use the raw license key value as a JSON string; do not set `CHEF_LICENSE_KEY` directly. Keep `chef_license_key` in the same public settings payload that you use for `runlist`, `bootstrap_options`, and `CHEF_LICENSE`.
