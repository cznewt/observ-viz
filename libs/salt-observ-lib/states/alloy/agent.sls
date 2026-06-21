# Install Grafana Alloy on the host that receives Salt events (typically the
# Salt master, alongside the alloy engine) and deploy the salt-observ pipeline.
{% set p = salt['pillar.get']('salt_observ', {}) %}

Alloy keyring dir:
  file.directory:
    - name: /etc/apt/keyrings
    - makedirs: true

Alloy apt key:
  cmd.run:
    - name: wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
    - creates: /etc/apt/keyrings/grafana.gpg
    - require:
        - file: Alloy keyring dir

Alloy apt repo:
  pkgrepo.managed:
    - name: deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main
    - file: /etc/apt/sources.list.d/grafana.list
    - require:
        - cmd: Alloy apt key

Alloy package:
  pkg.installed:
    - name: alloy
    - refresh: true
    - require:
        - pkgrepo: Alloy apt repo

Alloy config:
  file.managed:
    - name: /etc/alloy/config.alloy
    - source: salt://{{ slspath }}/files/config.alloy
    - makedirs: true
    - require:
        - pkg: Alloy package
    - watch_in:
        - service: Alloy service

Alloy defaults:
  file.managed:
    - name: /etc/default/alloy
    - contents: |
        CONFIG_FILE="/etc/alloy/config.alloy"
        CUSTOM_ARGS=""
        RESTART_ON_UPGRADE=true
        LOKI_URL="{{ p.get('loki_url', 'http://127.0.0.1:3100/loki/api/v1/push') }}"
        LOKI_TENANT="{{ p.get('loki_tenant', '') }}"
        PROM_URL="{{ p.get('prom_url', 'http://127.0.0.1:9009/api/v1/push') }}"
        PROM_TENANT="{{ p.get('prom_tenant', '') }}"
    - require:
        - pkg: Alloy package
    - watch_in:
        - service: Alloy service

Alloy service:
  service.running:
    - name: alloy
    - enable: true
    - require:
        - pkg: Alloy package
