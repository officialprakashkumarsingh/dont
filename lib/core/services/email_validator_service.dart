class EmailValidatorService {
  // List of common temporary email domains to block
  static const List<String> _tempEmailDomains = [
    'tempmail.com',
    'guerrillamail.com',
    '10minutemail.com',
    'mailinator.com',
    'throwaway.email',
    'yopmail.com',
    'temp-mail.org',
    'fakeinbox.com',
    'trashmail.com',
    'maildrop.cc',
    'dispostable.com',
    'mailnesia.com',
    'tempr.email',
    'throwawaymail.com',
    'spamgourmet.com',
    'sharklasers.com',
    'guerrillamailblock.com',
    'spam4.me',
    'grr.la',
    'mailmetrash.com',
    'tempinbox.com',
    'throwaway.in',
    'tempemail.net',
    'tempmail.net',
    'tmpmail.net',
    'tmpmail.org',
    'tmpeml.info',
    'tempmailo.com',
    'mailto.plus',
    'moakt.com',
    'inboxbear.com',
    'getairmail.com',
    'tempmail.de',
    'harakirimail.com',
    'mailtemp.net',
    '10mail.org',
    'maildu.de',
  ];

  /// Normalize email by removing dots from Gmail addresses and converting to lowercase
  static String normalizeEmail(String email) {
    email = email.toLowerCase().trim();
    
    // Check if it's a Gmail address (including googlemail)
    if (email.contains('@gmail.com') || email.contains('@googlemail.com')) {
      final parts = email.split('@');
      if (parts.length == 2) {
        // Remove dots from the local part (before @)
        String localPart = parts[0].replaceAll('.', '');
        
        // Remove anything after + (Gmail alias feature)
        if (localPart.contains('+')) {
          localPart = localPart.substring(0, localPart.indexOf('+'));
        }
        
        // Always use gmail.com (googlemail.com is the same)
        return '$localPart@gmail.com';
      }
    }
    
    // For non-Gmail addresses, just remove aliases (+ part)
    if (email.contains('+')) {
      final atIndex = email.indexOf('@');
      final plusIndex = email.indexOf('+');
      if (plusIndex < atIndex) {
        final localPart = email.substring(0, plusIndex);
        final domain = email.substring(atIndex);
        return localPart + domain;
      }
    }
    
    return email;
  }

  /// Check if email is from a temporary email service
  static bool isTempEmail(String email) {
    final domain = email.split('@').last.toLowerCase();
    return _tempEmailDomains.contains(domain);
  }

  /// Comprehensive email validation
  static EmailValidationResult validateEmail(String email) {
    // Basic format validation
    if (email.isEmpty) {
      return EmailValidationResult(
        isValid: false,
        error: 'Email is required',
      );
    }

    // Check email format with regex
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return EmailValidationResult(
        isValid: false,
        error: 'Please enter a valid email address',
      );
    }

    // Check for temporary email
    if (isTempEmail(email)) {
      return EmailValidationResult(
        isValid: false,
        error: 'Temporary email addresses are not allowed',
      );
    }

    // Check for suspicious patterns
    final localPart = email.split('@')[0];
    
    // Check if local part is too short or suspicious
    if (localPart.length < 3) {
      return EmailValidationResult(
        isValid: false,
        error: 'Email address appears to be invalid',
      );
    }

    // Check for excessive dots or special characters
    if (localPart.contains('..') || 
        localPart.startsWith('.') || 
        localPart.endsWith('.')) {
      return EmailValidationResult(
        isValid: false,
        error: 'Email address format is invalid',
      );
    }

    // Normalize the email for duplicate checking
    final normalizedEmail = normalizeEmail(email);

    return EmailValidationResult(
      isValid: true,
      normalizedEmail: normalizedEmail,
    );
  }

  /// Check if an email already exists (normalized)
  static Future<bool> isEmailAlreadyRegistered(String email) async {
    // This would typically check against your database
    // For now, we'll return the normalized email for the auth service to check
    final normalized = normalizeEmail(email);
    
    // The actual check will be done by Supabase
    // We just ensure the normalized version is used
    return false;
  }
}

class EmailValidationResult {
  final bool isValid;
  final String? error;
  final String? normalizedEmail;

  EmailValidationResult({
    required this.isValid,
    this.error,
    this.normalizedEmail,
  });
}