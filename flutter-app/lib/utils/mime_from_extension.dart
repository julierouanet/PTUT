/// Déduit un type MIME à partir d'une extension de fichier (sans le point).
/// Utilisé par les flux d'upload de documents (équipement, intervention).
String mimeFromExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'pdf':
    default:
      return 'application/pdf';
  }
}
