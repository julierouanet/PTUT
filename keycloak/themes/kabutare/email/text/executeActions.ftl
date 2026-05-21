Hôpital de Kabutare — Action requise sur votre compte
======================================================

Bonjour ${user.firstName!user.username},

Un administrateur vous demande d'effectuer les actions suivantes sur votre compte :

<#list requiredActions as action>
- ${msg("requiredAction.${action}")}
</#list>

Cliquez sur le lien ci-dessous pour procéder :

${link}

Ce lien expire dans ${linkExpirationFormatter(linkExpiration)}.

--
Hôpital de Kabutare · Système de gestion des équipements médicaux
