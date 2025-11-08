/**
 * This sample demonstrates a simple driver  built against the Alexa Smart Home Skill Api.
 * For additional details, please refer to the Alexa Smart Home Skill API developer documentation 
 * https://developer.amazon.com/en-US/docs/alexa/smarthome/steps-to-build-a-smart-home-skill.html#create-a-lambda-function
*/
var https = require('https');
var REMOTE_CLOUD_BASE_PATH = '/mh/bin';
let REMOTE_CLOUD_HOSTNAME = process.env.REMOTE_CLOUD_HOSTNAME;
let REMOTE_CLOUD_PORT = process.env.REMOTE_CLOUD_PORT;
let USERNAME = process.env.USERNAME;
let PASSWORD = process.env.PASSWORD;

/**
 * Main entry point.
 * Incoming events from Alexa Lighting APIs are processed via this method.
 */
exports.handler = function(request, context) {

    log('Input', request);

    if ((request.directive.header.namespace === 'Alexa.PowerController') || (request.directive.header.namespace === 'Alexa.Discovery') || (request.directive.header.namespace === 'Alexa.PercentageController') || (request.directive.header.namespace === 'Alexa.ReportState')) {
        handleNewRequest(request, context);
    } else {
        log('Err', 'No supported namespace: ' + request.directive.header.namespace);
        context.fail('Something went wrong');
    }
};

/**
 * This method is invoked when we receive a new message from Alexa Smart Home Skill.
 * Forward the request on to MisterHouse and then pass the response back to the
 * Smart Home API
 */
function handleNewRequest(request, context) {

    var basePath = REMOTE_CLOUD_BASE_PATH + '/' + 'alexav3.pl';

    var options = {
        hostname: REMOTE_CLOUD_HOSTNAME,
        port: REMOTE_CLOUD_PORT,
        path: basePath,
        auth: USERNAME + ':' + PASSWORD,
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
        context.fail(generateError(request, 'ENDPOINT_UNREACHABLE', request.directive.header.namespace + ':Unable to connect to server'));
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
            log('Discovery', str);
            context.succeed(JSON.parse(str));
        });

        response.on('error', serverError);
    });
    
    // post the discovery request to MisterHouse
    post_req.write(JSON.stringify(request));
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

function generateError(request, code, description) {
    var headers = {
        namespace: "Alexa",
        name: "ErrorResponse",
        payloadVersion: '3',
        messageId: request.directive.header.messageId + "-R",
        correlationToken: request.directive.header.correlationToken
    };

    var endpoint = {
        endpointId: request.directive.endpoint.endpointId
    };

    var payload = {
        type: code,
        message: description
    };

    var event = {
        header: headers,
        endpoint: endpoint,
        payload: payload
    };
   
    var result = {
        event: event
    };

    return result;
}