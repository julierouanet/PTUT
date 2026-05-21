<#import "template.ftl" as layout>
<@layout.emailLayout>
  <p>Bonjour <strong>${user.firstName!user.username}</strong>,</p>
  <p>
    Une demande de réinitialisation de mot de passe a été effectuée pour votre compte
    sur le système de gestion des équipements médicaux de l'Hôpital de Kabutare.
  </p>

  <div class="btn-wrapper">
    <a class="btn" href="${link}">Réinitialiser mon mot de passe</a>
  </div>

  <div class="link-fallback">
    Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br>
    <a href="${link}">${link}</a>
  </div>

  <div class="warning">
    <strong>Vous n'avez pas fait cette demande ?</strong><br>
    Votre compte est peut-être compromis. Contactez immédiatement votre administrateur système.
  </div>

  <hr class="divider">

  <p style="font-size:13px; color:#718096;">
    Ce lien expire dans <strong>${linkExpirationFormatter(linkExpiration)}</strong>.
  </p>
</@layout.emailLayout>
