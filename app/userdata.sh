#!/bin/bash
set -eux

# Install nginx + php for demo (MySQL client for testing)
dnf update -y
dnf install -y nginx php php-fpm php-mysqlnd mariadb105

# Simple app that shows instance + AZ info
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>HA 3-Tier App</title>
  <meta charset="utf-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: system-ui, sans-serif;
      background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 100%);
      color: #e6e6f0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 2rem;
    }
    .card {
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(124,92,255,0.3);
      border-radius: 20px;
      padding: 3rem;
      max-width: 520px;
      text-align: center;
      backdrop-filter: blur(20px);
      box-shadow: 0 30px 80px -20px rgba(124,92,255,0.4);
    }
    h1 { font-size: 1.75rem; margin-bottom: 0.5rem; background: linear-gradient(135deg,#7c5cff,#22d3ee); -webkit-background-clip: text; background-clip: text; color: transparent; }
    .badge { display: inline-block; font-size: 0.75rem; font-family: monospace; color: #22d3ee; border: 1px solid rgba(34,211,238,0.3); padding: 0.25rem 0.75rem; border-radius: 99px; margin-bottom: 1.5rem; }
    .info { text-align: left; margin-top: 2rem; font-family: monospace; font-size: 0.9rem; }
    .row { display: flex; justify-content: space-between; padding: 0.75rem 0; border-bottom: 1px solid rgba(255,255,255,0.06); }
    .key { color: #8b8ba7; }
    .val { color: #22d3ee; }
    .footer { margin-top: 2rem; font-size: 0.75rem; color: #8b8ba7; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">● HEALTHY</div>
    <h1>HA 3-Tier Platform</h1>
    <p style="color:#8b8ba7">Served from a private EC2 in a Multi-AZ Auto Scaling Group</p>
    <div class="info">
      <div class="row"><span class="key">Instance ID</span><span class="val" id="iid">loading...</span></div>
      <div class="row"><span class="key">Availability Zone</span><span class="val" id="az">loading...</span></div>
      <div class="row"><span class="key">Private IP</span><span class="val" id="ip">loading...</span></div>
      <div class="row"><span class="key">Region</span><span class="val" id="region">loading...</span></div>
    </div>
    <p class="footer">Refresh to hit a different AZ (ALB round-robin)</p>
  </div>

  <script>
    fetch('http://169.254.169.254/latest/dynamic/instance-identity/document')
      .then(r => r.json())
      .then(d => {
        document.getElementById('iid').textContent = d.instanceId;
        document.getElementById('az').textContent = d.availabilityZone;
        document.getElementById('ip').textContent = d.privateIp;
        document.getElementById('region').textContent = d.region;
      })
      .catch(() => { /* IMDSv2 fallback — will still render */ });
  </script>
</body>
</html>
EOF

# IMDSv2 token-based metadata (required since EC2 launched with IMDSv2 enforced)
cat > /usr/share/nginx/html/metadata.sh <<'EOF'
#!/bin/bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id
EOF
chmod +x /usr/share/nginx/html/metadata.sh

systemctl enable nginx
systemctl start nginx