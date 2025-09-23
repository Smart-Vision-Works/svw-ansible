#!/bin/bash

# Get a list of all users
for user in $(ls /home); do
    echo $user
    # If the user's home directory contains '@kpmanalytics.com'
    if [[ $user == *"@kpmanalytics.com"* ]]; then
        # Get the user's groups
        user_groups=$(groups $user)

        # If the user is not a member of 'labelers'
        if [[ $user_groups != *"labelers"* ]]; then
            # Add the user to 'labelers'
            usermod -a -G labelers $user
            echo "User $user added to the 'labelers' group"
        else
            echo "User $user is already a member of the 'labelers' group"
        fi
    fi
done