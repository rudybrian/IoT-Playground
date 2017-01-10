/**
 * This sample demonstrates a simple driver  built against the Alexa Smart Home Skill Api.
 * For additional details, please refer to the Alexa Smart Home Skill API developer documentation 
 * https://developer.amazon.com/public/solutions/alexa/alexa-skills-kit/overviews/understanding-the-smart-home-skill-api
 */
var https = require('https');
var REMOTE_CLOUD_BASE_PATH = '/mh/bin';
var REMOTE_CLOUD_HOSTNAME = 'my.misterhousehost.com';
var applicationId = 'amzn1.ask.skill.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';

/**
 * Main entry point.
 * Incoming events from Alexa Lighting APIs are processed via this method.
 */
exports.handler = function(event, context) {

    log('Input', event);

    if (event.session.application.applicationId === applicationId) {
        handleNewRequest(event, context);
    } else {
        log('Err', 'No supported applicationId: ' + event.session.application.applicationId);
        context.fail('Something went wrong');
    }
};

/**
 * This method is invoked when we receive a new message from Alexa Smart Home Skill.
 * Forward the request on to MisterHouse and then pass the response back to the
 * Smart Home API
 */
function handleNewRequest(event, context) {

    var basePath = REMOTE_CLOUD_BASE_PATH + '/' + 'alexa.pl';

    var options = {
        hostname: REMOTE_CLOUD_HOSTNAME,
        port: 443,
        path: basePath,
        auth: 'username:password',
        method: 'POST',
        headers: {
            accept: '*/*'
        }
    };

    var serverError = function (e) {
        log('Error', e.message);
        /**
         * Craft an error response back to Alexa Smart Home Skill
         */
        context.fail(generateError(event, 'DependentServiceUnavailableError', event.header.namespace + ':Unable to connect to server'));
    };

    /**
     * Make an HTTPS call to remote endpoint.
     */
    var post_req = https.request(options, function(response) {
        response.setEncoding('utf-8');
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
            context.succeed(JSON.parse(str));
        });

        response.on('error', serverError);
    });
    
    // post the discovery request to MisterHouse
    post_req.write(JSON.stringify(event));
    post_req.end();
}


/**
 * Utility functions.
 */
function log(title, msg) {
    console.log('*************** ' + title + ' *************');
    console.log(msg);
    console.log('*************** ' + title + ' End*************');
}

function generateError(event, code, description) {
    var headers = {
        namespace: "Alexa.ConnectedHome.Control",
        name: code,
        payloadVersion: '2',
        messageId: 'e1929526-66fb-4f99-869a-13c58bee88ef'
    };

    var payload = {
        dependentServiceName: description
    };

    var result = {
        header: headers,
        payload: payload
    };

    return result;
}
