[![Docker Image CI](https://github.com/daisaja/energymeterdashboard/actions/workflows/docker.yml/badge.svg)](https://github.com/daisaja/energymeterdashboard/actions/workflows/docker.yml)

Check out http://smashing.github.io/smashing for more information.

Please note: in order to run klimato weather widget you need to register for yahoo weather api here: https://developer.yahoo.com/weather/

Afterwards you need to expose your appid, customerKey and customerSecrets as environment variables like this:

$ export EM_APP_ID=my_app_id_value  
$ export EM_CONSUMER_KEY=my_customer_key_value  
$ export EM_CONSUMER_SECRET=my_customer_secret_value  

In order to run the docker container you need to put variables into a env-file like this:

$ touch .env

EM_APP_ID=my_app_id_value  
EM_CONSUMER_KEY=my_customer_key_value  
EM_CONSUMER_SECRET=my_customer_secret_value  


Run docker with:

$ docker run -p3030:3030 --env-file .env id_of_your_container

See for further explanations: https://vsupalov.com/docker-build-time-env-values/

For local build and test also possible:

docker build --build-arg EM_APP_ID=my_app_id_value EM_CONSUMER_KEY=my_customer_key_value EM_CONSUMER_SECRET=my_customer_secret_value

docker build -t daisaja/energymeter:latest .
docker push daisaja/energymeter:latest

SMA firmware: 2.13.33.R / 3.10.10.R

# Copy ssd image

sudo fdisk -l

sudo mount | grep sdc
sudo umount /dev/sdc1

~/Downloads/volkszaehler_latest$ sudo dd if=./2019-07-07-volkszaehler_raspian_buster.img | pv -s 8G | sudo dd of=/dev/sdc bs=1M


```mermaid
  graph TD;
      A-->B;
      A-->C;
      B-->D;
      C-->D;
```
