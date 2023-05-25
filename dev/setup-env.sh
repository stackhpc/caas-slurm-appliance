#!/bin/bash
set -euo pipefail

/usr/bin/python3.8 -m venv venv 
source venv/bin/activate
pip install -U pip
pip install -r requirements.txt
ansible --version
# Install ansible dependencies ...
ansible-galaxy role install -r requirements.yml --force
ansible-galaxy collection install -r requirements.yml --force
