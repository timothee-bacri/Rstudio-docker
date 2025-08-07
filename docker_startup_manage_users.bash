#!/usr/bin/env bash
USERS="dw356 ik354 mh1176 trfb201 jm622 mcm216 hc629 CassandraBird jmose "
USER_IDS="502 505 503 507 504 506 508 509 510"
DEFAULT_PASSWORD="orchid"
USERS_ARRAY=($USERS)
USER_IDS_ARRAY=($USER_IDS)

# Create new users if they are not present on the container
for i in "${!USERS_ARRAY[@]}"; do
  user="${USERS_ARRAY[i]}"
  user_id="${USER_IDS_ARRAY[i]}"
  # Add user only if not already available
  if ! id "${user}" &>/dev/null; then
    # Create the user
    adduser --disabled-password --comment "" --uid "${user_id}" --shell /bin/bash "${user}"
    # Set the user with the default password
    echo "${user}:${DEFAULT_PASSWORD}" | chpasswd
    # Add the user to the group rstudio-users
    usermod --append --groups rstudio-users "${user}"
  fi
done

# Let users install packages, update package list, search
SUDOERS_FILE="/etc/sudoers.d/group-rstudio-users"
mkdir -p /etc/sudoers.d
echo "User_Alias MYUSERS = ${USERS// /,}" > "${SUDOERS_FILE}"
echo "Cmnd_Alias INSTALL = /usr/bin/apt-get install *, /usr/bin/apt install *" >> "${SUDOERS_FILE}"
echo "Cmnd_Alias UPDATE = /usr/bin/apt-get update *, /usr/bin/apt update *" >> "${SUDOERS_FILE}"
echo "Cmnd_Alias SEARCH = /usr/bin/apt-get search *, /usr/bin/apt search *" >> "${SUDOERS_FILE}"
echo "MYUSERS ALL = INSTALL, UPDATE, SEARCH" >> "${SUDOERS_FILE}"
