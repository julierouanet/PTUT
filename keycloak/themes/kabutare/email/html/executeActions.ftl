<#import "template.ftl" as layout>
<@layout.emailLayout>
  <p>Bonjour <strong>${user.firstName!user.username}</strong>,</p>
  <p>
    Un administrateur du système de l'Hôpital de Kabutare vous demande d'effectuer
    les actions suivantes sur votre compte :
  </p>

  <ul style="margin:0 0 20px; padding-left:20px; line-height:2;">
    <#list requiredActions as action>
      <li>${msg("requiredAction.${action}")}</li>
    </#list>
  </ul>

  <div class="btn-wrapper">
    <a class="btn" href="${link}">Accéder à mon compte</a>
  </div>

  <div class="link-fallback">
    Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br>
    <a href="${link}">${link}</a>
  </div>

  <hr class="divider">

  <p style="font-size:13px; color:#718096;">
    Ce lien expire dans <strong>${linkExpirationFormatter(linkExpiration)}</strong>.
  </p>
</@layout.emailLayout>
