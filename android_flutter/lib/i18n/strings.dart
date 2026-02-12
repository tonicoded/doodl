class AppStrings {
  AppStrings(this.lang);

  final String lang; // 'en' | 'nl' | 'es' | 'de' (fallback to en)

  String get _l {
    final v = lang.trim().toLowerCase();
    if (v == 'nl' || v == 'es' || v == 'de') return v;
    return 'en';
  }

  String _t({required String en, String? nl, String? es, String? de}) {
    return switch (_l) {
      'nl' => nl ?? en,
      'es' => es ?? en,
      'de' => de ?? en,
      _ => en,
    };
  }

  // Common
  String get ok => _t(en: 'OK', nl: 'OK', es: 'OK', de: 'OK');
  String get cancel =>
      _t(en: 'Cancel', nl: 'Annuleren', es: 'Cancelar', de: 'Abbrechen');
  String get create =>
      _t(en: 'Create', nl: 'Maken', es: 'Crear', de: 'Erstellen');
  String get join => _t(en: 'Join', nl: 'Join', es: 'Unirse', de: 'Beitreten');
  String get delete =>
      _t(en: 'Delete', nl: 'Verwijderen', es: 'Eliminar', de: 'Löschen');
  String get report =>
      _t(en: 'Report', nl: 'Melden', es: 'Reportar', de: 'Melden');
  String get block =>
      _t(en: 'Block', nl: 'Blokkeren', es: 'Bloquear', de: 'Blockieren');
  String get unblock =>
      _t(en: 'Unblock', nl: 'Deblokkeren', es: 'Desbloquear', de: 'Entsperren');
  String get save =>
      _t(en: 'Save', nl: 'Opslaan', es: 'Guardar', de: 'Speichern');
  String get copied =>
      _t(en: 'Copied', nl: 'Gekopieerd', es: 'Copiado', de: 'Kopiert');
  String get saved =>
      _t(en: 'Saved', nl: 'Opgeslagen', es: 'Guardado', de: 'Gespeichert');
  String get loading =>
      _t(en: 'Loading…', nl: 'Laden…', es: 'Cargando…', de: 'Lädt…');
  String get notSignedIn => _t(
      en: 'Not signed in',
      nl: 'Niet ingelogd',
      es: 'No has iniciado sesión',
      de: 'Nicht angemeldet');

  // Tabs / dashboard
  String get share => _t(en: 'share', nl: 'delen', es: 'enviar', de: 'senden');
  String get inbox =>
      _t(en: 'inbox', nl: 'inbox', es: 'bandeja', de: 'postfach');
  String get drawAndSend => _t(
        en: 'draw a doodl and send it',
        nl: 'teken een doodl en stuur het',
        es: 'dibuja un doodl y envíalo',
        de: 'zeichne ein doodl und sende es',
      );
  String get quickDoodlesWithFriends => _t(
        en: 'quick doodles with friends',
        nl: 'snelle doodles met vrienden',
        es: 'doodles rápidos con amigos',
        de: 'schnelle doodles mit freunden',
      );
  String get pickGroup => _t(
      en: 'pick group',
      nl: 'kies groep',
      es: 'elige grupo',
      de: 'gruppe wählen');

  // Inbox
  String get inboxTitle =>
      _t(en: 'inbox', nl: 'inbox', es: 'bandeja', de: 'postfach');
  String get friends =>
      _t(en: 'friends', nl: 'vrienden', es: 'amigos', de: 'freunde');
  String get friend =>
      _t(en: 'friend', nl: 'vriend', es: 'amigo', de: 'freund');
  String get requests =>
      _t(en: 'requests', nl: 'verzoeken', es: 'solicitudes', de: 'anfragen');
  String get invites => _t(
      en: 'invites',
      nl: 'uitnodigingen',
      es: 'invitaciones',
      de: 'einladungen');
  String get addFriend => _t(
      en: 'add friend',
      nl: 'vriend toevoegen',
      es: 'añadir amigo',
      de: 'freund hinzufügen');
  String get removeFriend => _t(
      en: 'Remove friend',
      nl: 'Vriend verwijderen',
      es: 'Eliminar amigo',
      de: 'Freund entfernen');
  String get removeFromGroup => _t(
      en: 'Remove from group',
      nl: 'Verwijder uit groep',
      es: 'Quitar del grupo',
      de: 'Aus Gruppe entfernen');
  String get reportDoodl => _t(
      en: 'Report doodl',
      nl: 'Meld doodl',
      es: 'Reportar doodl',
      de: 'Doodl melden');
  String get blockUser => _t(
      en: 'Block user',
      nl: 'Blokkeer gebruiker',
      es: 'Bloquear usuario',
      de: 'Benutzer blockieren');
  String get unblockUser => _t(
      en: 'Unblock user',
      nl: 'Deblokkeer gebruiker',
      es: 'Desbloquear usuario',
      de: 'Benutzer entsperren');
  String get reply =>
      _t(en: 'reply', nl: 'reply', es: 'responder', de: 'antworten');
  String get newLabel => _t(en: 'new', nl: 'nieuw', es: 'nuevo', de: 'neu');
  String get searchFriends => _t(
      en: 'search friends…',
      nl: 'zoek vrienden…',
      es: 'buscar amigos…',
      de: 'freunde suchen…');
  String get searchGroups => _t(
      en: 'search groups…',
      nl: 'zoek groepen…',
      es: 'buscar grupos…',
      de: 'gruppen suchen…');
  String get search =>
      _t(en: 'search…', nl: 'zoeken…', es: 'buscar…', de: 'suchen…');
  String get noNewDoodl => _t(
      en: 'no new doodl',
      nl: 'geen nieuwe doodl',
      es: 'no hay doodl nueva',
      de: 'keine neue doodl');
  String get newDoodl => _t(
      en: 'new doodl', nl: 'nieuwe doodl', es: 'doodl nueva', de: 'neue doodl');
  String get opened =>
      _t(en: 'opened', nl: 'geopend', es: 'abierto', de: 'geöffnet');
  String get addFriendsToStartTitle => _t(
        en: 'add friends to start',
        nl: 'voeg vrienden toe om te starten',
        es: 'añade amigos para empezar',
        de: 'füge freunde hinzu, um zu starten',
      );
  String get addFriendsToStartSubtitle => _t(
        en: 'add someone by @username, then send them a doodl.',
        nl: 'voeg iemand toe via @username en stuur een doodl.',
        es: 'añade a alguien por @usuario y envía un doodl.',
        de: 'füge jemanden per @username hinzu und sende eine doodl.',
      );
  String get group => _t(en: 'group', nl: 'groep', es: 'grupo', de: 'gruppe');
  String get anon => _t(en: 'anon', nl: 'anon', es: 'anónimo', de: 'anonym');
  String get joinToViewInbox => _t(
        en: 'Join a group to view your inbox.',
        nl: 'Join een groep om je inbox te zien.',
        es: 'Únete a un grupo para ver tu bandeja.',
        de: 'Tritt einer Gruppe bei, um dein Postfach zu sehen.',
      );
  String get noDoodlesYet => _t(
      en: 'No doodles yet.',
      nl: 'Nog geen doodles.',
      es: 'Aún no hay doodles.',
      de: 'Noch keine doodles.');
  String get enableAnonInSettings => _t(
        en: 'Enable anonymous in Settings',
        nl: 'Zet anoniem aan in Instellingen',
        es: 'Activa anónimo en Ajustes',
        de: 'Aktiviere anonym in Einstellungen',
      );
  String get noAnonDoodlesYet => _t(
        en: 'No anonymous doodles yet.',
        nl: 'Nog geen anonieme doodles.',
        es: 'Aún no hay doodles anónimos.',
        de: 'Noch keine anonymen doodles.',
      );

  // Share / tools
  String get send => _t(en: 'Send', nl: 'Stuur', es: 'Enviar', de: 'Senden');
  String get sending =>
      _t(en: 'Sending…', nl: 'Sturen…', es: 'Enviando…', de: 'Sende…');
  String get sent =>
      _t(en: 'Sent', nl: 'Verstuurd', es: 'Enviado', de: 'Gesendet');
  String get sendTo =>
      _t(en: 'Send to', nl: 'Stuur naar', es: 'Enviar a', de: 'Senden an');
  String get pickAtLeastOneRecipient => _t(
        en: 'Pick at least one recipient.',
        nl: 'Kies minstens één ontvanger.',
        es: 'Elige al menos un destinatario.',
        de: 'Wähle mindestens einen Empfänger.',
      );
  String get eraser =>
      _t(en: 'Eraser', nl: 'Gum', es: 'Borrador', de: 'Radierer');
  String get pen => _t(en: 'Pen', nl: 'Pen', es: 'Pluma', de: 'Stift');

  // Settings
  String get settings => _t(
      en: 'Settings', nl: 'Instellingen', es: 'Ajustes', de: 'Einstellungen');
  String get profile =>
      _t(en: 'Profile', nl: 'Profiel', es: 'Perfil', de: 'Profil');
  String get language =>
      _t(en: 'Language', nl: 'Taal', es: 'Idioma', de: 'Sprache');
  String get changeUsername => _t(
      en: 'Change username',
      nl: 'Gebruikersnaam wijzigen',
      es: 'Cambiar usuario',
      de: 'Benutzername ändern');
  String get username => _t(
      en: 'Username', nl: 'Gebruikersnaam', es: 'Usuario', de: 'Benutzername');
  String get anonymousDoodles => _t(
      en: 'Anonymous doodles',
      nl: 'Anonieme doodles',
      es: 'Doodles anónimos',
      de: 'Anonyme doodles');
  String get anonymousSubtitle => _t(
      en: 'Receive doodles from your link',
      nl: 'Ontvang doodles via je link',
      es: 'Recibe doodles por tu link',
      de: 'Empfange doodles über deinen Link');
  String get anonymousLink => _t(
      en: 'Anonymous link',
      nl: 'Anonieme link',
      es: 'Link anónimo',
      de: 'Anonymer Link');
  String get logout =>
      _t(en: 'Log out', nl: 'Uitloggen', es: 'Cerrar sesión', de: 'Abmelden');
  String get deleteAccount => _t(
      en: 'Delete account',
      nl: 'Account verwijderen',
      es: 'Eliminar cuenta',
      de: 'Konto löschen');
  String get removesDeviceSession => _t(
        en: 'Removes this device session',
        nl: 'Verwijdert deze sessie van dit apparaat',
        es: 'Elimina la sesión de este dispositivo',
        de: 'Entfernt diese Gerätesitzung',
      );
  String get removesProfileGroups => _t(
        en: 'Removes your profile + groups',
        nl: 'Verwijdert je profiel + groepen',
        es: 'Elimina tu perfil + grupos',
        de: 'Entfernt dein Profil + Gruppen',
      );
  String get terms =>
      _t(en: 'Terms', nl: 'Voorwaarden', es: 'Términos', de: 'AGB');
  String get privacy =>
      _t(en: 'Privacy', nl: 'Privacy', es: 'Privacidad', de: 'Datenschutz');
  String get deleteAccountConfirmTitle => _t(
      en: 'Delete account?',
      nl: 'Account verwijderen?',
      es: '¿Eliminar cuenta?',
      de: 'Konto löschen?');
  String get deleteAccountConfirmBody => _t(
      en: 'This can’t be undone.',
      nl: 'Dit kan niet ongedaan worden.',
      es: 'No se puede deshacer.',
      de: 'Das kann nicht rückgängig gemacht werden.');

  // Groups
  String get groups =>
      _t(en: 'Groups', nl: 'Groepen', es: 'Grupos', de: 'Gruppen');
  String get joinGroup =>
      _t(en: 'Join group', nl: 'Join groep', es: 'Unirse', de: 'Beitreten');
  String get newGroup => _t(
      en: 'New group',
      nl: 'Nieuwe groep',
      es: 'Nuevo grupo',
      de: 'Neue Gruppe');
  String get noGroupsYet => _t(
      en: 'No groups yet.',
      nl: 'Nog geen groepen.',
      es: 'Aún no hay grupos.',
      de: 'Noch keine Gruppen.');
  String get createGroupAndInviteFriends => _t(
        en: 'Create a group and invite friends.',
        nl: 'Maak een groep en nodig vrienden uit.',
        es: 'Crea un grupo e invita a amigos.',
        de: 'Erstelle eine Gruppe und lade Freunde ein.',
      );
  String get members =>
      _t(en: 'Members', nl: 'Leden', es: 'Miembros', de: 'Mitglieder');
  String get leaveGroup => _t(
      en: 'Leave group',
      nl: 'Groep verlaten',
      es: 'Salir del grupo',
      de: 'Gruppe verlassen');
  String get activeGroupCode => _t(
      en: 'Active group code',
      nl: 'Actieve groepscode',
      es: 'Código del grupo',
      de: 'Aktiver Gruppencode');
  String get invite =>
      _t(en: 'Invite', nl: 'Uitnodigen', es: 'Invitar', de: 'Einladen');
  String get inviteByUsername => _t(
      en: 'Invite by username',
      nl: 'Uitnodigen via username',
      es: 'Invitar por usuario',
      de: 'Per Username einladen');
  String get searchUsername => _t(
      en: 'Search username',
      nl: 'Zoek username',
      es: 'Buscar usuario',
      de: 'Username suchen');
  String get typeToSearch => _t(
      en: 'Type 2+ letters to search',
      nl: 'Typ 2+ letters om te zoeken',
      es: 'Escribe 2+ letras para buscar',
      de: 'Tippe 2+ Buchstaben zum Suchen');

  // Onboarding
  String get start => _t(en: 'Start', nl: 'Start', es: 'Empezar', de: 'Start');
  String get pickAUsername => _t(
      en: 'Pick a username',
      nl: 'Kies een username',
      es: 'Elige un usuario',
      de: 'Wähle einen Benutzernamen');
  String get continueText =>
      _t(en: 'Continue', nl: 'Doorgaan', es: 'Continuar', de: 'Weiter');
  String get addProfilePhoto => _t(
      en: 'Add a profile photo',
      nl: 'Voeg een profielfoto toe',
      es: 'Añade una foto de perfil',
      de: 'Profilfoto hinzufügen');
  String get optionalChangeLater => _t(
      en: 'Optional. You can change this later in settings.',
      nl: 'Optioneel. Je kunt dit later wijzigen.',
      es: 'Opcional. Puedes cambiarlo luego.',
      de: 'Optional. Du kannst das später ändern.');
  String get choosePhoto => _t(
      en: 'Choose photo',
      nl: 'Kies foto',
      es: 'Elegir foto',
      de: 'Foto wählen');
  String get skip =>
      _t(en: 'Skip', nl: 'Overslaan', es: 'Saltar', de: 'Überspringen');
  String get yourCode =>
      _t(en: 'Your code', nl: 'Jouw code', es: 'Tu código', de: 'Dein Code');
  String get codeSubtitle => _t(
        en: 'It’s also your default group code.',
        nl: 'Dit is ook je standaard groepscode.',
        es: 'También es tu código de grupo.',
        de: 'Das ist auch dein Standard-Gruppencode.',
      );
  String get done => _t(en: 'Done', nl: 'Klaar', es: 'Listo', de: 'Fertig');
}
