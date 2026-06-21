# Install the saltext.alloy engine on the Salt master and forward the event bus
# to the local Alloy loki.source.api endpoint (see states/alloy/agent.sls).
{% set p = salt['pillar.get']('salt_observ', {}) %}

Install Alloy engine:
  pip.installed:
    - name: saltext.alloy
    - upgrade: true

Configure Alloy engine:
  file.managed:
    - name: /etc/salt/master.d/alloy-engine.conf
    - contents: |
        engines:
          - alloy:
              url: "{{ p.get('engine_url', 'http://127.0.0.1:9000') }}"
              exclude_tags:
                - salt/auth
                - minion_start
                - minion/refresh/*
                - "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"

Restart Salt master:
  cmd.run:
    - name: 'salt-call --local service.restart salt-master'
    - bg: true
    - onchanges:
        - pip: Install Alloy engine
        - file: Configure Alloy engine
