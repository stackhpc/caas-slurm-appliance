WIP of using `ansible-runner` to create CaaS.

# Install:

Clone this, then:

    python3.9 -m venv venv
    . venv/bin/activate
    pip install ansible-runner
    pip install ansible
    pip install "openstacksdk<0.98.999"
    pip install passlib

    # TODO: ensure this is correct!
    ansible-galaxy role install -r requirements.yml -p roles
    ansible-galaxy collection install -r requirements.yml -p collections

# Usage

    ansible-runner run -vv -p slurm-infra.yml .


# TODO

- [ ] Make sure directory isolation works.
- [ ] Simplify creating nested groups.

