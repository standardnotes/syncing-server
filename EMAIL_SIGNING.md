# Email Signing
The syncing server is capable of using S/MIME to sign all outgoing emails, allowing users to be sure that the emails are unmodified and are not phishing.

## How users can validate the signature
If you're using the default `sync.standardnotes.org` syncing server, or if your admin has setup a CA signed S/MIME certificate, all the emails you receive should already be signed and trusted without you needing to do anything. If you receive an email from Standard Notes and want to validate its authenticity, all you need to do is:

1. Confirm that the email is sent from the correct address (`backups@standardnotes.org` for the default syncing server).
2. Confirm that your email client has a `Verified` or `Signed` icon. This validates that the email wasn't modified in transit, and that it actually was sent by the claimed email address. The icon is a bit different for each email client, but you can see what it should look like for your client below:

<Insert list of instructions for different clients, operating systems, etc>

### Self-Hosted Instances without CA Certificates
If you're using a self-hosted instance that doesn't have a verified S/MIME certificate, you'll need to do one more step to be able to validate the email signatures. You'll need to import the signing certificate that the server is using, and configure your email client to trust it for email signing. You can find exact instructions for your email client below:

<Insert list of instructions for different clients, operating systems, etc>

After the certificate has been installed and trusted, you can validate emails using the same steps as shown above, with your instance's email address used instead of `backups@standardnotes.org`.

## How admins can setup S/MIME signing
To enable email signing for outgoing emails, you'll need a S/MIME certificate.

### CA-Signed Certificate
If you own a domain and are willing to pay for a certificate, there are multiple Certificate Authorities that can provide a certificate that will automatically be trusted by all your clients.

### Self-Signed Certificate
If you don't want a CA signed certificate, you can create your own self-signed certificate. The easiest way to accomplish this is using an automated tool such as [mkcert](https://mkcert.dev/), or if you prefer you can do it manually [using OpenSSL](https://www.dalesandro.net/create-self-signed-smime-certificates/). The disadvantage of a self-signed certificate is that it'll need to be manually installed on all clients that want to validate the sent emails.

### Installation
Once you have your certificate and its key, you need to put them into the `config/smime_certificates` directory. Then you simply add their filenames to the `SMIME_CERTIFICATE_FILENAME` and `SMIME_KEY_FILENAME` variables in the `.env` file. The server will automatically enable signing for all sent emails. Make sure that `EMAIL_FROM_ADDRESS` has been configured to match the email address of the S/MIME certificate, or else the email signatures won't validate.

    Note: Some SMTP relays (such as SendGrid) tamper with the message body to inject tracking images or change the charset, thereby invalidating the signature. Make sure that the SMTP server you're using will relay messages unmodified.