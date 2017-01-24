import json
import sys
with open(sys.argv[1]) as data_file:
    data = json.load(data_file, strict=False)
data = data['runtimeSettings'][0]['handlerSettings']['publicSettings']['environment_variables']
comands=""
for key, value in data.items():
    comands=comands+'export '+key+'="'+value+'";'
print comands
