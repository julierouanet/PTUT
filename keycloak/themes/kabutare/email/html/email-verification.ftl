<#import "template.ftl" as layout>
<@layout.emailLayout>
  <p>Bonjour <strong>${user.firstName!user.username}</strong>,</p>
  <p>
    Votre compte sur le système de gestion des équipements médicaux de l'Hôpital de Kabutare
    vient d'être créé ou mis à jour. Veuillez vérifier votre adresse email pour activer votre accès.
  </p>

  <div class="btn-wrapper">
    <a class="btn" href="${link}">Vérifier mon adresse email</a>
  </div>

  <div class="link-fallback">
    Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br>
    <a href="${link}">${link}</a>
  </div>

  <hr class="divider">

  <p style="font-size:13px; color:#718096;">
    Ce lien expire dans <strong>${linkExpirationFormatter(linkExpiration)}</strong>.
    Si vous n'êtes pas à l'origine de cette demande, ignorez cet email — votre compte restera inchangé.
  </p>
</@layout.emailLayout>
