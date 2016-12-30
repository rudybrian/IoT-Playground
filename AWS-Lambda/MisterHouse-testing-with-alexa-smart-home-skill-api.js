/**
 * This sample demonstrates a simple driver  built against the Alexa Smart Home Skill Api.
 * For additional details, please refer to the Alexa Smart Home Skill API developer documentation 
 * https://developer.amazon.com/public/solutions/alexa/alexa-skills-kit/overviews/understanding-the-smart-home-skill-api
 */
var https = require('https');
var REMOTE_CLOUD_BASE_PATH = '/mh/bin';
var REMOTE_CLOUD_HOSTNAME = 'my.misterhouse.hostname';

/**
 * Main entry point.
 * Incoming events from Alexa Lighting APIs are processed via this method.
 */
exports.handler = function(event, context) {

    log('Input', event);

    switch (event.header.namespace) {
        
        /**
         * The namespace of "Discovery" indicates a request is being made to the lambda for
         * discovering all appliances associated with the customer's appliance cloud account.
         * can use the accessToken that is made available as part of the payload to determine
         * the customer.
         */
        case 'Alexa.ConnectedHome.Discovery':
            handleDiscovery(event, context);
            break;

            /**
             * The namespace of "Control" indicates a request is being made to us to turn a
             * given device on, off or brighten. This message comes with the "appliance"
             * parameter which indicates the appliance that needs to be acted on.
             */
        case 'Alexa.ConnectedHome.Control':
            handleControl(event, context);
            break;

            /**
             * We received an unexpected message
             */
        default:
            log('Err', 'No supported namespace: ' + event.header.namespace);
            context.fail('Something went wrong');
            break;
    }
};

/**
 * This method is invoked when we receive a "Discovery" message from Alexa Smart Home Skill.
 * We are expected to respond back with a list of appliances that we have discovered for a given
 * customer. 
 */
function handleDiscovery(accessToken, context) {

    /**
     * Crafting the response header
     */
    var headers = {
        messageId: 'ff746d98-ab02-4c9e-9d0d-b44711658414',
        namespace: 'Alexa.ConnectedHome.Discovery',
        name: 'DiscoverAppliancesResponse',
        payloadVersion: '2'
    };

    /**
     * Response body will be an array of discovered devices.
     */
    var appliances = [];

    var applianceDiscovered = {
        actions: [
                    'incrementPercentage',
                    'decrementPercentage',
                    'setPercentage',
                    'turnOn',
                    'turnOff'
        ],
        applianceId: 'Sample-Device-ID',
        manufacturerName: 'SmartThings',
        modelName: 'ST01',
        version: 'VER01',
        friendlyName: 'Test Device',
        friendlyDescription: 'the light in kitchen',
        isReachable: true,
        additionalApplianceDetails: {
            /**
             * OPTIONAL:
             * We can use this to persist any appliance specific metadata.
             * This information will be returned back to the driver when user requests
             * action on this appliance.
             */
            'fullApplianceId': '2cd6b650-c0h0-4062-b31d-7ec2c146c5ea'
        }
    };
    appliances.push(applianceDiscovered);

    /**
     * Craft the final response back to Alexa Smart Home Skill. This will include all the 
     * discoverd appliances.
     */
    var payloads = {
        discoveredAppliances: appliances
    };
    var result = {
        header: headers,
        payload: payloads
    };

    log('Discovery', result);

    context.succeed(result);
}

/**
 * Control events are processed here.
 * This is called when Alexa requests an action (IE turn off appliance).
 */
function handleControl(event, context) {

    /**
     * Fail the invocation if the header is unexpected. This example only demonstrates
     * turn on / turn off, hence we are filtering on anything that is not SwitchOnOffRequest.
     */
    if (event.header.namespace != 'Alexa.ConnectedHome.Control' || (event.header.name != 'TurnOnRequest') && (event.header.name != 'TurnOffRequest')) {
        context.fail(generateControlError('SwitchOnOffRequest', 'UNSUPPORTED_OPERATION', 'Unrecognized operation'));
    }

    if (event.header.namespace === 'Alexa.ConnectedHome.Control' && ((event.header.name != 'TurnOnRequest') || (event.header.name != 'TurnOffRequest'))) {

        /**
         * Retrieve the appliance id and accessToken from the incoming message.
         */
        var applianceId = event.payload.appliance.applianceId;
        var accessToken = event.payload.accessToken.trim();
        log('applianceId', applianceId);

        /**
         * Make a remote call to execute the action based on accessToken and the applianceId and the switchControlAction
         * Some other examples of checks:
         *	validate the appliance is actually reachable else return TARGET_OFFLINE error
         *	validate the authentication has not expired else return EXPIRED_ACCESS_TOKEN error
         * Please see the technical documentation for detailed list of errors
         */
        var basePath = '';
        if (event.header.name === 'TurnOnRequest') {
            /* basePath = REMOTE_CLOUD_BASE_PATH + '/' + applianceId + '/on?access_token=' + accessToken; */
            basePath = REMOTE_CLOUD_BASE_PATH + '/' + 'runit.pl?' + 'Turn_the_indoor_tree_on';
        } else if (event.header.name === 'TurnOffRequest') {
            /* basePath = REMOTE_CLOUD_BASE_PATH + '/' + applianceId + '/of?access_token=' + accessToken; */
            basePath = REMOTE_CLOUD_BASE_PATH + '/' + 'runit.pl?' + 'Turn_the_indoor_tree_off';
        }


        var options = {
            hostname: REMOTE_CLOUD_HOSTNAME,
            port: 443,
            path: basePath,
            auth: 'username:password',
            headers: {
                accept: '*/*'
            }
        };

        var serverError = function (e) {
            log('Error', e.message);
            /**
             * Craft an error response back to Alexa Smart Home Skill
             */
            context.fail(generateControlError('SwitchOnOffRequest', 'DEPENDENT_SERVICE_UNAVAILABLE', 'Unable to connect to server'));
        };

        var callback = function(response) {
            var str = '';

            response.on('data', function(chunk) {
                str += chunk.toString('utf-8');
            });

            response.on('end', function() {
                /**
                 * Test the response from remote endpoint (not shown) and craft a response message
                 * back to Alexa Smart Home Skill
                 */
                log('done with result');
                var this_name = '';
                if (event.header.name === 'TurnOnRequest') {
                    this_name = 'TurnOnConfirmation';
                } else if (event.header.name === 'TurnOffRequest') {
                    this_name = 'TurnOffConfirmation';
                }
                var headers = {
                    messageId: '26fa11a8-accb-4f66-a272-8b1ff7abd722',
                    namespace: 'Alexa.ConnectedHome.Control',
                    name: this_name,
                    payloadVersion: '2'
                };
                var payloads = {
                };
                var result = {
                    header: headers,
                    payload: payloads
                };
                log('Done with result', result);
                context.succeed(result);
            });

            response.on('error', serverError);
        };

        /**
         * Make an HTTPS call to remote endpoint.
         */
        https.get(options, callback)
            .on('error', serverError).end();
    }
}

/**
 * Utility functions.
 */
function log(title, msg) {
    console.log('*************** ' + title + ' *************');
    console.log(msg);
    console.log('*************** ' + title + ' End*************');
}

function generateControlError(name, code, description) {
    var headers = {
        namespace: 'Control',
        name: name,
        payloadVersion: '1'
    };

    var payload = {
        exception: {
            code: code,
            description: description
        }
    };

    var result = {
        header: headers,
        payload: payload
    };

    return result;
}

