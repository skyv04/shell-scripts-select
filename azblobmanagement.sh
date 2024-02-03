# upload
az storage blob upload --account-name famsyncrstorage --container-name json --name data/yves.json --file ./yves.json --overwrite

# download
az storage blob download --account-name famsyncrstorage --container-name json --name data/yves.json > yves.json



