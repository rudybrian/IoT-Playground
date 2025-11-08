
#
# Interfaces with the Alexa Smart Home (ConnectedHome) API via AWS Lambda.
#
# Currently supports Discovery and Control functions for a
# fixed set of devices in a group
#
# Brian Rudy (brudyNO@SPAMpraecogito.com)
#
# 11/4/2025 Revised to support the v3 Smart Home API

use vars qw(%Http $HTTP_BODY $HTTP_REQUEST %HTTP_ARGV);

use JSON::XS qw//;
use Data::GUID;
use DateTime;

#use Data::Dumper;
use strict;

my $list_name      = "Lights";
my $module_version = "0.3";

#my $results = "$ENV{HTTP_QUERY_STRING}\n";
#my $results = Dumper(%Http);
my $results = Dumper($HTTP_BODY);

#my $results = Dumper(%ENV);

#open( FH, '>', "/var/tmp/query_string.txt" ) or die $!;
#print FH $results;
#close(FH);

my $nowiso8601 = DateTime->now()->iso8601() . 'Z';

my $json_text;
eval { $json_text = JSON::XS->new->decode($HTTP_BODY); };

#catch crashes
if ($@) {
    main::print_log("ERROR! JSON parser crashed! $@");
    return ('0');
}

my $guid = Data::GUID->new;

if ( defined $json_text->{"directive"}->{"header"}->{"namespace"} ) {
    my $reqname = $json_text->{"directive"}->{"header"}->{"name"};
    if ( $json_text->{"directive"}->{"header"}->{"namespace"} eq "Alexa.Discovery" ) {

        # Handle discovery stuff here
        if ( $json_text->{"directive"}->{"header"}->{"name"} eq "Discover" ) {

            # compose the response to send back
            my $response_data = { header => $json_text->{"directive"}->{"header"} };
            $response_data->{"header"}->{"name"} = "Discover.Response";
            $response_data->{"header"}->{"messageId"} .= "-R";

            my @objects = &list_objects_by_type($list_name);
            @objects = &list_objects_by_group($list_name) unless @objects;
            my @appliances;
            for my $item ( sort @objects ) {
                next unless $item;
                my $object = &get_object_by_name($item);

                next if $object->{hidden};
                if ( $object->can('state') || $object->can('state_level') ) {
                    my ( $can_onoff, $can_percent ) = checkSupportedStates($object);
                    my $stripped_applianceId = $object->{object_name};
                    $stripped_applianceId =~ s/\$//g;
                    my $appliance = {
                        endpointId        => $stripped_applianceId,
                        description       => toFriendlyName( $object->{object_name} ),
                        friendlyName      => toFriendlyName( $object->{object_name} ),
                        manufacturerName  => "MisterHouse",
                        displayCategories => ["LIGHT"],
                        cookie            => { fullApplianceId => $object->{object_name} },
                        version           => "Ver-$module_version"
                    };
                    if ( $can_onoff && $can_percent ) {
                        $appliance->{"capabilities"} = [
                            {
                                interface  => "Alexa.PowerController",
                                version    => "3",
                                type       => "AlexaInterface",
                                properties => {
                                    supported           => [ { name => "powerState" } ],
                                    retrievable         => JSON::false,
                                    proactivelyReported => JSON::true
                                }
                            },
                            {
                                interface  => "Alexa.PercentageController",
                                version    => "3",
                                type       => "AlexaInterface",
                                properties => {
                                    supported           => [ { name => "percentage" }, { name => "percentageDelta" } ],
                                    retrievable         => JSON::false,
                                    proactivelyReported => JSON::true
                                }
                            },
                            {
                                interface  => "Alexa.EndpointHealth",
                                version    => "3.1",
                                type       => "AlexaInterface",
                                properties => {
                                    supported           => [ { name => "connectivity" } ],
                                    retrievable         => JSON::false,
                                    proactivelyReported => JSON::true
                                }
                            },
                            {
                                interface => "Alexa",
                                version   => "3",
                                type      => "AlexaInterface"
                            }
                        ];
                    }
                    elsif ($can_onoff) {
                        $appliance->{"capabilities"} = [
                            {
                                interface  => "Alexa.PowerController",
                                version    => "3",
                                type       => "AlexaInterface",
                                properties => {
                                    supported           => [ { name => "powerState" } ],
                                    retrievable         => JSON::false,
                                    proactivelyReported => JSON::true
                                }
                            },
                            {
                                interface  => "Alexa.EndpointHealth",
                                version    => "3.1",
                                type       => "AlexaInterface",
                                properties => {
                                    supported           => [ { name => "connectivity" } ],
                                    retrievable         => JSON::false,
                                    proactivelyReported => JSON::true
                                }
                            },
                            {
                                interface => "Alexa",
                                version   => "3",
                                type      => "AlexaInterface"
                            }
                        ];
                    }
                    elsif ($can_percent) {
                        $appliance->{"capabilities"} = [
                            {
                                interface  => "Alexa.PercentageController",
                                version    => "3",
                                type       => "AlexaInterface",
                                properties => {
                                    supported           => [ { name => "percentage" }, { name => "percentageDelta" } ],
                                    retrievable         => JSON::false,
                                    proactivelyReported => JSON::true
                                }
                            },
                            {
                                interface  => "Alexa.EndpointHealth",
                                version    => "3.1",
                                type       => "AlexaInterface",
                                properties => {
                                    supported           => [ { name => "connectivity" } ],
                                    retrievable         => JSON::false,
                                    proactivelyReported => JSON::true
                                }
                            },
                            {
                                interface => "Alexa",
                                version   => "3",
                                type      => "AlexaInterface"
                            }
                        ];
                    }
                    push @appliances, $appliance;
                }
            }
            push @{ $response_data->{"payload"}->{"endpoints"} }, @appliances;

            my $response_package = { event => $response_data };
            my $response         = "HTTP/1.0 200 OK\n";
            $response .= "Content-Type: application/json\n\n";
            $response .= JSON::XS::encode_json $response_package;
            return $response;
        }
    }
    elsif ( $json_text->{"directive"}->{"header"}->{"namespace"} eq "Alexa.PowerController" ) {
        my $reqtoken = $json_text->{"directive"}->{"endpoint"}->{"scope"}->{"token"};

        # compose the response to send back
        my $response_data = { header => $json_text->{"directive"}->{"header"} };
        $response_data->{"header"}->{"namespace"} = "Alexa";
        $response_data->{"header"}->{"name"}      = "Response";
        $response_data->{"header"}->{"messageId"} .= "-R";

        my $obj = &get_object_by_name( $json_text->{"directive"}->{"endpoint"}->{"endpointId"} );

        my $context_result = {
            properties => [
                {
                    namespace                 => "Alexa.PowerController",
                    name                      => "powerState",
                    timeOfSample              => $nowiso8601,
                    uncertaintyInMilliseconds => "50"

                },
                {
                    namespace                 => "Alexa.EndpointHealth",
                    name                      => "connectivity",
                    value                     => { value => "OK" },
                    timeofsample              => $nowiso8601,
                    uncertaintyInMilliseconds => "0",
                }
            ]
        };

        if ( $reqname eq "TurnOn" ) {
            set $obj ON;
            $context_result->{"properties"}->[0]->{"value"} = "ON";
        }
        elsif ( $reqname eq "TurnOff" ) {
            set $obj OFF;
            $context_result->{"properties"}->[0]->{"value"} = "OFF";
        }
        else {
            # This doesn't match a name we were expecting, Generate an error
        }

        my $response_package = {
            context => $context_result,
            event   => {
                header   => $response_data->{"header"},
                endpoint => {
                    scope => {
                        type  => "BearerToken",
                        token => $reqtoken
                    },
                    endpointId => $json_text->{"directive"}->{"endpoint"}->{"endpointId"}
                },
                payload => {}
            }
        };

        # Roll up the resoponse and send it back to Amazon
        my $response = "HTTP/1.0 200 OK\n";
        $response .= "Content-Type: application/json\n\n";
        $response .= JSON::XS::encode_json $response_package;
        return $response;
    }
    elsif ( $json_text->{"directive"}->{"header"}->{"namespace"} eq "Alexa.PercentageController" ) {
        my $reqtoken = $json_text->{"directive"}->{"endpoint"}->{"scope"}->{"token"};

        # compose the response to send back
        my $response_data = { header => $json_text->{"directive"}->{"header"} };
        $response_data->{"header"}->{"namespace"} = "Alexa";
        $response_data->{"header"}->{"name"}      = "Response";
        $response_data->{"header"}->{"messageId"} .= "-R";

        my $obj = &get_object_by_name( $json_text->{"directive"}->{"endpoint"}->{"endpointId"} );

        my $context_result = {
            properties => [
                {
                    namespace                 => "Alexa.PercentageController",
                    timeOfSample              => $nowiso8601,
                    uncertaintyInMilliseconds => "50"

                },
                {
                    namespace                 => "Alexa.EndpointHealth",
                    name                      => "connectivity",
                    value                     => { value => "OK" },
                    timeofsample              => $nowiso8601,
                    uncertaintyInMilliseconds => "0"
                }
            ]
        };

        if ( $reqname eq "SetPercentage" ) {

            # First check if we support percentage requests
            my ( $can_onoff, $can_percent ) = checkSupportedStates($obj);
            if ($can_percent) {

                # Set the object to the nearest available percentage state
                my $nearestpercent         = findNearestPercent( $obj, $json_text->{"directive"}->{"payload"}->{"percentage"} );
                my $strippednearestpercent = $nearestpercent;
                $strippednearestpercent =~ s/\%//g;
                set $obj &findNearestPercent( $obj, $nearestpercent );
                $context_result->{"properties"}->[0]->{"name"}  = "percentage";
                $context_result->{"properties"}->[0]->{"value"} = $strippednearestpercent;
            }
            else {
                # This device is unable to do percent requests, generate an error
            }
        }
        elsif ( $reqname eq "AdjustPercentage" ) {

            # First check if we support percentage requests
            my ( $can_onoff, $can_percent ) = checkSupportedStates($obj);
            if ($can_percent) {

                # Set the object to the nearest available percentage state
                my $nearestpercent         = findNearestPercent( $obj, $json_text->{"directive"}->{"payload"}->{"percentageDelta"} );
                my $strippednearestpercent = $nearestpercent;
                $strippednearestpercent =~ s/\%//g;
                set $obj &findNearestPercent( $obj, $nearestpercent );
                $context_result->{"properties"}->[0]->{"name"}  = "percentage";
                $context_result->{"properties"}->[0]->{"value"} = $strippednearestpercent;
            }
            else {
                # This device is unable to do percent requests, generate an error
            }
        }
        else {
            # This doesn't match a name we were expecting, Generate an error
        }

        my $response_package = {
            context => $context_result,
            event   => {
                header   => $response_data->{"header"},
                endpoint => {
                    scope => {
                        type  => "BearerToken",
                        token => $reqtoken
                    },
                    endpointId => $json_text->{"directive"}->{"endpoint"}->{"endpointId"}
                },
                payload => {}
            }
        };

        # Roll up the resoponse and send it back to Amazon
        my $response = "HTTP/1.0 200 OK\n";
        $response .= "Content-Type: application/json\n\n";
        $response .= JSON::XS::encode_json $response_package;
        return $response;
    }
    elsif (
        #******* the part below here still needs work********
        #****************************************************
        $json_text->{"header"}->{"namespace"} eq "Alexa.ConnectedHome.System"
      )
    {
        if ( $json_text->{"header"}->{"name"} eq "HealthCheckRequest" ) {
            my $response_data = {
                header => {
                    messageId      => lc( $guid->as_string ),
                    name           => "HealthCheckResponse",
                    namespace      => "Alexa.ConnectedHome.System",
                    payloadVersion => "2"
                },
                payload => {
                    description => "The system is currently healthy",
                    isHealthy   => JSON::true
                }
            };

            # Roll up the resoponse and send it back to Amazon
            my $response = "HTTP/1.0 200 OK\n";
            $response .= "Content-Type: application/json\n\n";
            $response .= JSON::XS::encode_json $response_data;
            return $response;
        }
        else {
            # Not sure what this is. Generate an error.
        }
    }
    else {
        # We have received something unexpected. Generate an error
    }
}
else {
    # We have received something unexpected. Generate an error
}

# Find the nearest percentage value to that requested
sub findNearestPercent {
    my ( $obj, $percent ) = @_;
    if ( $obj->can('state_level') ) {
        if ( $percent =~ m/^[+-]/g ) {
            $percent += 100 + $obj->state_level();
            $percent = 100 if $percent >= 100;
            $percent = 0   if $percent <= 0;
        }
        $percent = sprintf( "%d", $percent );
        return $percent;
    }
    else {
        if ( $percent =~ m/^[+-]/g ) {
            my $current_percent = $obj->state();
            $current_percent = 100 if ( lc $current_percent eq 'on' );
            $current_percent = 0   if ( lc $current_percent eq 'off' );
            $current_percent =~ s/\%//g;
            $percent += $current_percent;
            $percent = 100 if $percent >= 100;
            $percent = 0   if $percent <= 0;
        }
        $percent = sprintf( "%d", $percent );
        my @states         = $obj->get_states();
        my @numeric_states = @states;
        for my $state (@numeric_states) {
            $state = 100 if ( lc $state eq 'on' );
            $state = 0   if ( lc $state eq 'off' );
            $state =~ s/\%//g;
        }
        my $itr = 0;
        foreach my $number (@numeric_states) {
            $itr++ and next if $percent >= $number;
        }
        return $states[ $itr - 1 ];
    }
}

# Check the supported states for the given object
sub checkSupportedStates {
    my ($obj)       = @_;
    my $can_onoff   = 0;
    my $can_percent = 0;
    my @states      = $obj->get_states();
    for my $state (@states) {
        if ( "on" eq lc($state) ) {
            $can_onoff = 1;
        }
        elsif ( "60\%" eq lc($state) ) {
            $can_percent = 1;
        }
    }
    if ( $obj->can('state_level') ) {
        $can_percent = 1;
    }
    return $can_onoff, $can_percent;
}

# Convert the device name into a friendly name
sub toFriendlyName {
    my ($in_name) = @_;
    $in_name =~ s/[_-]/ /g;
    $in_name =~ s/\$//g;
    $in_name =~ s/([0-9])/ $1/g;
    return $in_name;
}

# Die, outputting HTML error page
# If no $title, use global $errtitle, or else default title
sub HTMLdie {
    my ( $msg, $title ) = @_;
    $title = ( $title || "CGI Error" );
    print <<EOF ;
HTTP/1.0 500 OK
Content-Type: text/html

<html>
<head>
<title>$title</title>
</head>
<body>
<h1>$title</h1>
<h3>$msg</h3>
</body>
</html>
EOF

    return;
}

