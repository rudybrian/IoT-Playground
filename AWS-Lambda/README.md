Must be used with an HTTPS reverse-proxy with basic authentication in front of your Misterhouse instance.

I have tested with the following Lambda settings:
- Resources:
  - myMisterHouseForwarder:
    - Type: 'AWS::Serverless::Function'
    - Environment variables:
      - REMOTE_CLOUD_HOSTNAME: FQDN of your reverse proxy
      - REMOTE_CLOUD_PORT: Port of your reverse proxy (443)
      - USERNAME: Reverse proxy username for MisterHouse
      - PASSWORD: Reverse proxy password for MisterHouse
    - Properties:
      - Handler: index.handler
      - Runtime: Node.js 22.x
      - CodeUri: .
      - Description: Smart Home API forwarder for MisterHouse
      - MemorySize: 128
      - Ephemeral storage: 512MB
      - Timeout: 10
