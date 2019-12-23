Check out http://smashing.github.io/smashing for more information.

Please note: in order to run klimato weather widget you need to register for yahoo weather api here: https://developer.yahoo.com/weather/

Afterwards you need to expose your appid, customerKey and customerSecrets as environment variables like this:

$ export EM_APP_ID=my_app_id_value
$ export EM_CONSUMER_KEY=my_customer_key_value
$ esport EM_CONSUMER_SECRET=my_customer_secret_value


In order to run the docker container you need to put variables into a env-file like this:

$ touch .env

EM_APP_ID=my_app_id_value
EM_CONSUMER_KEY=my_customer_key_value
EM_CONSUMER_SECRET=my_customer_secret_value


Run docker with:

$ docker run -p3030:3030 --env-file .env id_of_your_container

See for further explanations: https://vsupalov.com/docker-build-time-env-values/
