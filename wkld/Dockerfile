FROM locustio/locust

RUN pip3 install \
  faker \
  pyyaml \
  locust-plugins \
  ;

# remove entrypoint so we can also run the seed script
ENTRYPOINT []