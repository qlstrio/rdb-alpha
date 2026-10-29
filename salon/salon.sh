#!/bin/bash

sql_literal() {
  local value=$1
  value=${value//\'/\'\'}
  printf "'%s'" "$value"
}

PSQL=(psql --username=freecodecamp --dbname=salon --no-psqlrc --tuples-only --no-align --quiet)

echo
echo "~~~~~ MY SALON ~~~~~"
echo
echo "Welcome to My Salon, how can I help you?"
echo

SERVICE_NAME=""
while [[ -z "$SERVICE_NAME" ]]; do
  SERVICE_LIST=$("${PSQL[@]}" -c "SELECT service_id || ') ' || name FROM services ORDER BY service_id;")
  printf '%s\n' "$SERVICE_LIST"
  echo
  read SERVICE_ID_SELECTED

  SERVICE_NAME=$("${PSQL[@]}" -c "SELECT name FROM services WHERE service_id::text = $(sql_literal "$SERVICE_ID_SELECTED");")

  if [[ -z "$SERVICE_NAME" ]]; then
    echo
    echo "I could not find that service. What would you like today?"
  fi
done

echo
echo "What's your phone number?"
read CUSTOMER_PHONE

CUSTOMER_ID=$("${PSQL[@]}" -c "SELECT customer_id FROM customers WHERE phone = $(sql_literal "$CUSTOMER_PHONE");")

if [[ -z "$CUSTOMER_ID" ]]; then
  echo
  echo "I don't have a record for that phone number, what's your name?"
  read CUSTOMER_NAME

  CUSTOMER_ID=$("${PSQL[@]}" -c "INSERT INTO customers (phone, name) VALUES ($(sql_literal "$CUSTOMER_PHONE"), $(sql_literal "$CUSTOMER_NAME")) RETURNING customer_id;")
else
  CUSTOMER_NAME=$("${PSQL[@]}" -c "SELECT name FROM customers WHERE customer_id = $(sql_literal "$CUSTOMER_ID");")
fi

echo
echo "What time would you like your $SERVICE_NAME, $CUSTOMER_NAME?"
read SERVICE_TIME

"${PSQL[@]}" -c "INSERT INTO appointments (customer_id, service_id, time) VALUES ($(sql_literal "$CUSTOMER_ID"), $(sql_literal "$SERVICE_ID_SELECTED"), $(sql_literal "$SERVICE_TIME"));"

echo
echo "I have put you down for a $SERVICE_NAME at $SERVICE_TIME, $CUSTOMER_NAME."