#!/bin/bash

set -euo pipefail

psql_query() {
  psql --username=freecodecamp --dbname=number_guess -qAtX -v ON_ERROR_STOP=1 -c "$1"
}

psql_query "
  CREATE TABLE IF NOT EXISTS users (
    username VARCHAR(22) PRIMARY KEY,
    games_played INTEGER NOT NULL DEFAULT 0,
    best_game INTEGER
  );
"

printf 'Enter your username: '
if ! IFS= read -r username; then
  printf 'Error: no username was provided.\n' >&2
  exit 1
fi
escaped_username=${username//\'/\'\'}

new_user=$(psql_query "
  INSERT INTO users (username)
  VALUES ('$escaped_username')
  ON CONFLICT (username) DO NOTHING
  RETURNING 1;
")

if [[ -n $new_user ]]; then
  printf 'Welcome, %s! It looks like this is your first time here.\n' "$username"
else
  stored_username=$(psql_query "
    SELECT username
    FROM users
    WHERE username = '$escaped_username';
  ")
  user_stats=$(psql_query "
    SELECT games_played || '|' || COALESCE(best_game::text, '0')
    FROM users
    WHERE username = '$escaped_username';
  ")
  IFS='|' read -r games_played best_game <<< "$user_stats"
  printf 'Welcome back, %s! You have played %s games, and your best game took %s guesses.\n' \
    "$stored_username" "$games_played" "$best_game"
fi

secret_number=$((RANDOM % 1000 + 1))
number_of_guesses=0
printf 'Guess the secret number between 1 and 1000:\n'

while true; do
  if ! IFS= read -r guess; then
    printf 'Error: no guess was provided.\n' >&2
    exit 1
  fi

  if [[ ! $guess =~ ^[+-]?[0-9]+$ ]]; then
    printf "That is not an integer, guess again:\n"
    continue
  fi

  ((number_of_guesses += 1))
  guess_digits=${guess#[+-]}
  is_negative=false
  if [[ $guess == -* ]]; then
    is_negative=true
  fi

  while [[ ${#guess_digits} -gt 1 && ${guess_digits:0:1} == 0 ]]; do
    guess_digits=${guess_digits:1}
  done

  if [[ $is_negative == true ]]; then
    comparison=lower
  elif [[ ${#guess_digits} -gt 4 ]]; then
    comparison=higher
  else
    guess_value=$((10#$guess_digits))
    if ((guess_value > secret_number)); then
      comparison=higher
    elif ((guess_value < secret_number)); then
      comparison=lower
    else
      break
    fi
  fi

  if [[ $comparison == higher ]]; then
    printf "It's lower than that, guess again:\n"
  else
    printf "It's higher than that, guess again:\n"
  fi
done

psql_query "
  UPDATE users
  SET games_played = games_played + 1,
      best_game = CASE
        WHEN best_game IS NULL OR best_game > $number_of_guesses THEN $number_of_guesses
        ELSE best_game
      END
  WHERE username = '$escaped_username';
"

printf 'You guessed it in %s tries. The secret number was %s. Nice job!\n' \
  "$number_of_guesses" "$secret_number"