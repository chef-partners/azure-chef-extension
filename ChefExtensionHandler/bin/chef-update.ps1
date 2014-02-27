

// reinstall with new version
// Actions:
//    - disable service -> uninstall service/chef -> install new chef version -> enable
//      (conditions for above: new chef-client version, runlist update via azure handlerSettings?)
//    - Do we need to manage state? what? client.rb, config knife.rb, validate pem ?
//    - do we worry about preserving heartbeat/status files from last runs? or are they simply recreated?

