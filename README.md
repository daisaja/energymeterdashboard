[![Docker Image CI](https://github.com/daisaja/energymeterdashboard/actions/workflows/docker.yml/badge.svg)](https://github.com/daisaja/energymeterdashboard/actions/workflows/docker.yml)

Check out http://smashing.github.io/smashing for more information.

## Docker

Run docker with:

```bash
docker run -p3030:3030 --env-file .env daisaja/energymeter:latest
```

Build and push:

```bash
docker build -t daisaja/energymeter:latest .
docker push daisaja/energymeter:latest
```

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
