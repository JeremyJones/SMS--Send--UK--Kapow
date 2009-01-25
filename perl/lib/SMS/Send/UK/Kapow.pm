package SMS::Send::UK::Kapow;

use warnings;
use strict;
use Carp;

=head1 NAME

SMS::Send::UK::Kapow - SMS::Send driver for the Kapow.co.uk website

=head1 VERSION

his document describes SMS::Send::UK::Kapow Version 0.02

=cut

use base 'SMS::Send::Driver';
use version;
our $VERSION = qv('0.02');
use URI::Escape;

=head1 SYNOPSIS

    use SMS::Send;

    my $sender = SMS::Send->new('UK::Kapow',
               _login    => 'my-kapow-username',   # normally required, see below (synonymous with _user) 
               _password => 'my-kapow-password',   # normally required, see below
               _send_via => 'http',                # optional, can be http, https or email, default is http
               _http_method => 'post',             # optional, the http method to use for http & https. 
                                                   #                           get or post, default get.
               _email_via => 'sendmail',           # optional, for use when 'email' is used. can be 
                                                   #                            'sendmail' or 'smtp'
               _url      => 'http://foo.com/done'  # optional url to call after sending, for http and https
               _from     => 'me@mydomain.com',     # optional, for use when 'email' is used in send_via 
               _from_id  => 'my-kapow-id',         # optional message originator, if enabled for your account
               _route    => '840101',              # optional shortcode for premium sms reverse billing
           );

    my $sent = $sender->send_sms(
        to        => '447712345678',                 # the recipient phone number
        text      => "Hello, world!",                # the text of the message to send
        _url      => 'http://foo.com/done123',       # optional url per message to call after sending 
                                                     #                                 (for http and https)
        _from     => 'me@mydomain.com',              # optional from address per message (for email)
    );

    # Did it send to Kapow ok?
    if ( $sent ) {
      print "Sent test message\n";
    } else {
      print "Test message failed\n";
    }

    # What's the status of the last message we sent? (available for http & https methods)
    my $status = $sender->send_status;

    # What's the status for an arbitrary message we sent in the past?
    my $status = $sender->send_status($sent);

=head1 DESCRIPTION

L<SMS::Send::UK::Kapow> is a L<SMS::Send> driver that delivers messages
via the L<http://www.kapow.co.uk> website.

Messages for any country can be sent through this interface, although
Kapow is generally aimed at users in the UK.

This driver is based on the Kapow implementation document available at
L<http://www.kapow.co.uk/docs/Kapow%20SMS%20Gateway%20Interfaces.pdf>

=head2 Preparing to Use This Driver

You need to create an account at http://www.kapow.co.uk to be able to
use this driver. You will also need to purchase some SMS credits for 
your account. Other optional services such getting a custom 'from-id'
or setting trusted sender email addresses can be configured in your
Kapow account and used through this module.

=head1 METHODS

=head2 new

  # Create a new sender using this driver
  my $sender = SMS::Send->new('UK::Kapow',
    _login    => 'username',     # normally required but see below
    _password => 'password',     # normally required but see below
    );

In most cases you should provide your Kapow username and password. 

If, however, you have set your Kapow account to allow any SMS requests
received via email from a certain trusted email address then you do
not need to set your username and password. In that case you may need
to provide a '_from' parameter here or in the send_sms method unless
your user account's email address on your system is the same as the
trusted one registered with your Kapow account.

=over

=item _login

The C<_login> param should be your kapow.co.uk username. The C<_user>
parameter can be used instead.

=item _password

The C<_password> param should be your kapow.co.uk password.

=item _send_via

The C<_send_via> param controls how your SMS messages are sent to
Kapow. The default method is http, which issues an http request from
your server to Kapow's. Other options are 'https' and 'email'.

The preferred methods are 'http' or 'https' because they allow the
system to track the delivery statuses of individual messages. If your
server cannot issue http/s requests then you can set this to 'email'
and it will instead send an email message to Kapow to issue the SMS
message. Note that using email means you lose the delivery tracking
features of the http/s methods.

To use the email method you need the MIME::Lite module installed.

=item _http_method

The C<_http_method> param is relevant when using http or https to send
your messages and specifies whether to use 'get' or 'post' methods
when issuing the request to Kapow. This defaults to 'get' but can be
changed to 'post' if desired.

=item _email_via

The C<_email_via> param is relevant when using email to send the
messages. With the MIME::Lite module installed you can control how
email messages are generated. Valid values for this param are 
'sendmail' and 'smtp'. The default is 'sendmail' except on Windows, 
where the default is 'smtp'.

=item _url

The C<_url> param is relevant when using http or https to send your
messages. It provides an arbitrary callback URL which the Kapow server
should call once the message has been successfully delivered. You can
override this per-message in order to use unique URLs which relate to
specific messages.

=item _from

The C<_from> param is relevant when using email to send your messages
and it should contain the email address to us as the 'from' address on
the emails sent to Kapow. The default (if using email) is to use your
user account's default email address.

=item _from_id

The C<_from_id> param is relevant for users who use Kapow's 'from-id'
feature to control the sender information that the recipient sees. If
you have purchased this feature from Kapow for your account then you
can control it using this parameter.

=item _route

The C<_route> param is for users who have purchased Kapow's Premium
SMS service to reverse-bill recipients for sending an SMS message. If
you have purchased this feature from Kapow for your account then you
can control it using this parameter.

=back

Returns a new C<SMS::Send::UK::Kapow> object, or dies on error.

=cut

eval { require LWP::UserAgent };
my $HAS_UA = ! $@;

eval { require MIME::Lite };
my $HAS_MIMELITE = ! $@;

my $IS_WINDOWS   = ($^O eq 'MSWin32');

sub new
{
    my $class    = shift;
    my %opts     = (_send_via => 'http', _http_method => 'get',
		    @_);

    $opts{ua} = $HAS_UA        ? LWP::UserAgent->new : undef;
    $opts{ml} = $HAS_MIMELITE;

    # sanity check the method we'll use 
    if (substr($opts{_send_via},0,4) eq 'http')
    {
	if (! $opts{ua})
	{
	    Carp::croak "You must install the LWP::UserAgent module to send SMS messages by http or https";
	}
    }
    elsif (! $opts{ml})
    {
	Carp::croak "You must install the MIME::Lite module before you can issue SMS messages by email";
    }
    
    return bless \%opts, ref($class) || $class;
}

=head2 send_sms

  # Send an SMS message
  my $sent = $sender->send_sms(
      to        => '447712345678',           # phone number to which to send the message
      text      => "Hello, world!",          # content of the message
  );

=over

=item _to

The required C<_to> param should contain the phone number for the
recipient. This should be in international format with the country
code first. The number may optionally be prefixed with a + sign which
will be removed before sending the request to Kapow.

If a number begins with '07' then that is converted to '447'. This is
relevant to users in the UK.

=item _text

The required C<_text> param should contain the text content that you
wish to send. Normally this is limited to 160 characters though that
restriction is NOT enforced by this module in order to take advantage
of multiple-part messages ability available on some phones.

Any newlines or carriage returns present are converted to spaces.

=item _url

The C<_url> param is optional and can be used to provide a callback
URL specific to this message. See above for a complete description.

=item _from

The C<_from> param is optional and can be used to provide an email
from address specific to this message. See above for a complete
description.

=back

=cut

sub send_sms
{
    my $self = shift;
    my %opts = (to => undef, text => undef, @_);

    if (not (defined($opts{to}) and defined($opts{text})))
    {
	Carp::croak "You must provide a 'to' number and 'text' content";
    }

    $opts{to}   =~ s/^\+//s;
    $opts{to}   =~ s/^07/447/s;
    $opts{text} =~ tr/\r\n/  /s;

    if (substr($self->{_send_via},0,4) eq 'http')
    {
	if (not (defined($self->{_login} || $self->{_user})
		 and
		 defined($self->{_password})))
	{
	    Carp::croak "To send messages using http/s you must provide a Kapow username and password";
	}
	my $protocol       = $self->{_send_via}    || 'http';
	my $request_method = $self->{_http_method} || 'get';

	my $response = do
	{
	    my $r = undef; 

	    my %params = (username => $self->{_login}    || $self->{_user} || "",
			  password => $self->{_password} || "",
			  mobile   => $opts{to}          || "",
			  sms      => $opts{text}        || "",
			  from_id  => $self->{_from_id}  || undef,
			  route    => $self->{_route}    || undef,
			  url      => $opts{_url} || $self->{_url} || undef,
			  returnid => 'TRUE', # enable message delivery tracking
		);
		    
	    if ($request_method eq 'get') 
	    {
		$r = $self->{ua}->get(sprintf("%s://www.kapow.co.uk/scripts/sendsms.php?%s",
					      $protocol,
					      join('&', map {sprintf("%s=%s", $_, uri_escape($params{$_}))}
						   grep {defined($params{$_})} keys %params)));
	    }
	    elsif ($request_method eq 'post')
	    {
		$r = $self->{ua}->post("$protocol://www.kapow.co.uk/scripts/sendsms.php",
				       {map {$_ => $params{$_}} grep {defined $params{$_}} keys %params});
	    }
	    $r;
	};
	if (defined($response) and $response->is_success)
	{
	    my $reply = $response->content;

	    $self->{_raw_response} = $reply;

	    my ($word,$num_credits,$unique_id) = split /\s+/, $reply;

	    if ($word eq 'OK') # message accepted
	    {
		$self->{_new_credits_balance} = $num_credits;
		$self->{_msg_delivery_id}     = $unique_id;
		$self->{_sent_at}             = time();
		return $unique_id;
	    }
	    else # request went through but message not accepted
	    {
		Carp::carp "SMS message not sent -- Kapow returned '$word'";
		return;
	    }
	}
	elsif (defined($response)) # failed lwp request, fatal
	{
	    Carp::croak "Failed to issue HTTP request: " . $response->status_line;
	}
	else # perhaps a strange request method. we probably never made any request
	{
	    Carp::croak "No HTTP request issued -- please ensure '_http_method' is set to either 'get' or 'post'";
	}
    }
    elsif ($self->{_send_via} eq 'email')
    {
	if (! $self->{ml}) # no mime::lite
	{
	    Carp::croak "Cannot send SMS messages by email without MIME::Lite installed";
	}
	my $send_method = $self->{_email_via} || ($IS_WINDOWS ? 'smtp' : 'sendmail');

	my $sms         = $opts{text} || "";
	my $mobile      = $opts{to}   || "";

	my %options     = (To        => "$opts{to}\@kapow.co.uk",
			   Subject   => $sms,   Type => 'TEXT',
			   Data      => "", );

	if (my $username = $self->{_login} || $self->{_user}
	    and 
	    my $password = $self->{_password})
	{
	    $options{Data} = "$username\n$password\n";
	}
	if (my $from = $opts{_from} || $self->{_from})
	{
	    $options{From} = $from;
	}

	eval
	{
	    MIME::Lite->new(%options)->send($send_method);
	};
	if ($@)
	{
	    Carp::carp $@;
	    return;
	}
	else { $self->{_sent_at} = time(); return 1 } # send and forget
    }
    return;
}

=head2 send_status

    # What's the status of the last message we sent? (available for http & https methods)
    my $status = $sender->send_status;

    # What's the status for an arbitrary message we sent in the past? (pass it the return value of the send_sms method)
    my $status = $sender->send_status($sent);

For messages sent via http/s you can check the delivery status of the
message by calling this method. If called with no parameters then the
most recent message sent out is checked. You can also provide the
return value of the send_sms method as a parameter to check the
delivery status for other messages.

The module will use the same http or https setting that the sender
object used to send the message (i.e. the _send_via param) as well as
the same get/post setting.

Messages sent by email cannot be checked for their delivery status.

=cut

sub send_status
{
    my $self        = shift;
    my $unique_id   = shift || $self->{_msg_delivery_id} 
    or Carp::croak "No message available for checking send_status";

    if (not defined $self->{ua})
    {
	Carp::croak "No user-agent available for checking send_status";
    }

    my $protocol      = $self->{_send_via}      || 'http';
    my $get_or_post   = $self->{_http_method}   || 'get';
    my $response      = undef;
    
    if ($get_or_post eq 'get')
    {
	$response      = $self->{ua}->get(sprintf("%s://www.kapow.co.uk/scripts/chk_status.php?username=%s&returnid=%s",
						  $protocol, uri_escape($self->{_login} || $self->{_user}),
						  uri_escape($unique_id)));
    }
    elsif ($get_or_post eq 'post')
    {
	$response      = $self->{ua}->post("$protocol://www.kapow.co.uk/scripts/chk_status.php",
					   { username => $self->{_login} || $self->{_user},
					     returnid => $unique_id });
    }
    else { Carp::croak "Unknown _http_method" }
    
    if (defined($response) and $response->is_success)
    {
	return $response->content;
    }
    return;
}

=head1 AUTHOR

Jeremy Jones, C<< <jjones at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sms-send-uk-kapow at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SMS-Send-Kapow>.  

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SMS::Send::UK::Kapow


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SMS-Send-Kapow>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SMS-Send-Kapow>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SMS-Send-Kapow>

=item * Search CPAN

L<http://search.cpan.org/dist/SMS-Send-Kapow/>

=back

=head1 ACKNOWLEDGEMENTS

Adam Kennedy's SMS::Send module and Andrew Moore's
SMS::Send::US::Ipipi module were used in developing this one.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Jeremy Jones, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of SMS::Send::UK::Kapow
