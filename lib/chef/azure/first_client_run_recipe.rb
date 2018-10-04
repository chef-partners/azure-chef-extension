node.attributes["target_runlist"].each {|value| node.run_list << value}
node.save
