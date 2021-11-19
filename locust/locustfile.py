from locust import HttpUser, task
import locust.stats
import os
from pathlib import Path
from pprint import pprint as pp
import requests
from faker import Faker
from faker.providers import ssn, phone_number
from datetime import datetime, date
import time


WORKER_ID = os.environ['WORKER_ID']
SEED_SIZE = int(os.environ['SEED_SIZE'])
locust.stats.PERCENTILES_TO_REPORT = [0.25, 0.5, 0.75,  0.9, 0.95,  0.99, 0.999, 0.9999, 1.0]
#
AUTH_SERVICE_URL = os.environ['AUTH_SERVICE_URL']
CANCEL_SERVICE_URL = os.environ['CANCEL_SERVICE_URL']
INSIDE_PAYMENT_SERVICE_URL = os.environ['INSIDE_PAYMENT_SERVICE_URL']
ORDER_SERVICE_URL = os.environ['ORDER_SERVICE_URL']
#
USERNAME = os.environ['USERNAME']
PASSWORD = os.environ['PASSWORD']


def auth_user():
  # login
  auth_url = f"{AUTH_SERVICE_URL}/api/v1/users/login"
  params = { "username": USERNAME, "password": PASSWORD, "verificationCode": "" }
  r = requests.post(auth_url, json=params)
  user_id = r.json()['data']['userId']
  auth_token = r.json()['data']['token']

  return user_id, auth_token

# use requests directly to bypass locust metric gathered for these calls
def create_order_and_pay(user_id, auth_token):
  create_order_url = f"{ORDER_SERVICE_URL}/api/v1/orderservice/order"
  pay_order_url = f"{INSIDE_PAYMENT_SERVICE_URL}/api/v1/inside_pay_service/inside_payment"
  headers = { 'Authorization': 'Bearer ' + auth_token }

  # Create order
  fake = Faker()
  TODAY = date.today()

  order_params = {
    "accountId": user_id,
    #
    "contactsName": fake.name(),
    "contactsDocumentNumber": fake.ssn(),
    "documentType": 1, # ID Card
    # /admin_station.html
    "from": 'shanghai',
    "to": 'suzhou',
    # TRIP ID - /admin_travel.html
    "trainNumber": 'D1345',
    #
    "seatClass": 1, # BUSINESS
    "coachNumber": 22,
    "seatNumber": fake.bothify(text='##?', letters='ABCDEF'),
    #
    "boughtDate": datetime.now().isoformat().replace("+00:00", "Z"),
    "travelDate": datetime(year=TODAY.year, month=TODAY.month, day=TODAY.day).isoformat().replace("+00:00", "Z"),
    "travelTime": datetime.now().isoformat().replace("+00:00", "Z"),
    #
    "price": str(100.0),
    "status": 0, # NOT PAID
  }
  r = requests.post(create_order_url, headers=headers, json=order_params)
  if r.status_code != 200:
    print("[ERROR] Failed to create order")
    return None

  order_id = r.json()['data']['id']

  # Pay order
  params = {
    "userId": user_id,
    "orderId": order_id,
    "tripId": order_params['trainNumber'],
    "price": order_params['price'],
  }
  r = requests.post(pay_order_url, headers=headers, json=params)
  if r.status_code != 200:
    print("[ERROR] Failed to pay order")
    return None

  return order_id

# to share with Worker task
if WORKER_ID != 'MASTER':
  # auth user
  user_id, auth_token = auth_user()
  # seed orders
  order_ids = list(filter(None, [ create_order_and_pay(user_id, auth_token) for _ in range(SEED_SIZE) ]))


class TrainTicket(HttpUser):
  @task
  def cancel_order(self):
    # build header file
    headers = { 'Authorization': 'Bearer ' + auth_token }
    # remove first one always
    order_id = order_ids.pop(0)
    # cancel order
    self.client.get(f"{CANCEL_SERVICE_URL}/api/v1/cancelservice/cancel/{order_id}/{user_id}", headers=headers, name=f"/api/v1/cancelservice/cancel/:order_id/:user_id")
    # then fetch the money to check if any inconsistency between drawbacks and cancelling the order
    with self.client.get(f"{INSIDE_PAYMENT_SERVICE_URL}/api/v1/inside_pay_service/inside_payment/money", headers=headers, catch_response=True) as r:
      consistent = len([e for e in r.json()['data'] if e['orderId'] == order_id ]) != 0
      if consistent:
        r.success()
      else:
        r.failure("Inconsistent result")