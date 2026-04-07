echo -n '{"auths":{"https://index.docker.io/v1/":{"username":"mario21ic","password":"dckr_pat_xxxx","email":"mario@example.com","auth":"'$(echo -n 'mario21ic:dckr_pat_xxxx' | base64)'"}}}' | base64 -w 0

#kubectl create secret docker-registry <secret-name> \
#    --docker-server=<your-registry-server> \
#    --docker-username=<your-username> \
#    --docker-password=<your-password> \
#    --docker-email=<your-email>

# kubectl create secret docker-registry secret-tiger-docker \
#   --docker-email=tiger@acme.example \
#   --docker-username=tiger \
#   --docker-password=pass1234 \
#   --docker-server=my-registry.example:5000
