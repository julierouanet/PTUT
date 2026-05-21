<#macro emailLayout>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0; padding: 0;
      background-color: #f0f4f8;
      font-family: Arial, Helvetica, sans-serif;
      color: #1a202c;
    }
    .wrapper {
      max-width: 600px;
      margin: 40px auto;
    }
    .card {
      background: #ffffff;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
    }
    .header {
      background-color: #1a5276;
      padding: 28px 32px;
    }
    .header-title {
      margin: 0;
      color: #ffffff;
      font-size: 20px;
      font-weight: bold;
      letter-spacing: 0.3px;
    }
    .header-subtitle {
      margin: 4px 0 0;
      color: #aed6f1;
      font-size: 13px;
    }
    .body {
      padding: 36px 32px;
      line-height: 1.7;
      font-size: 15px;
      color: #2d3748;
    }
    .body p {
      margin: 0 0 16px;
    }
    .btn-wrapper {
      text-align: center;
      margin: 28px 0;
    }
    .btn {
      display: inline-block;
      padding: 14px 32px;
      background-color: #1a5276;
      color: #ffffff !important;
      text-decoration: none;
      border-radius: 6px;
      font-size: 15px;
      font-weight: bold;
      letter-spacing: 0.3px;
    }
    .btn:hover {
      background-color: #154360;
    }
    .link-fallback {
      margin-top: 20px;
      padding: 14px 16px;
      background: #eaf3fb;
      border-left: 4px solid #1a5276;
      border-radius: 4px;
      font-size: 12px;
      word-break: break-all;
      color: #2c3e50;
    }
    .warning {
      margin-top: 20px;
      padding: 12px 16px;
      background: #fef9e7;
      border-left: 4px solid #f39c12;
      border-radius: 4px;
      font-size: 13px;
      color: #7d6608;
    }
    .divider {
      border: none;
      border-top: 1px solid #e2e8f0;
      margin: 24px 0;
    }
    .footer {
      background-color: #f7fafc;
      border-top: 1px solid #e2e8f0;
      padding: 20px 32px;
      text-align: center;
      font-size: 12px;
      color: #718096;
      line-height: 1.6;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="card">
      <div class="header">
        <p class="header-title">Hôpital de Kabutare</p>
        <p class="header-subtitle">Système de gestion des équipements médicaux</p>
      </div>
      <div class="body">
        <#nested>
      </div>
      <div class="footer">
        Cet email a été envoyé automatiquement — merci de ne pas y répondre.<br>
        <strong>Hôpital de Kabutare</strong> · Kabutare, Rwanda<br>
        En cas de problème, contactez votre administrateur système.
      </div>
    </div>
  </div>
</body>
</html>
</#macro>
