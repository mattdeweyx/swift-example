class Logger {
    constructor() {
        this.callStack = [];
        this.depthMap = {}; // Global depth map to track indentation for each function
    }

    log(message) {
        const functionName = this.callStack[this.callStack.length - 1];
        const depth = this.depthMap[functionName] || 0;
        const prefix = '│   '.repeat(depth);
        const formattedMessage = `${prefix}└── ${message}`;
        console.log(formattedMessage);
    }

    enterContext(functionName) {
        this.callStack.push(functionName);
        // Always update the depthMap, even if the function exists:
        this.depthMap[functionName] = this.callStack.length - 1;
    }

    exitContext() {
        const functionName = this.callStack.pop();
        delete this.depthMap[functionName];
    }

    instrumentFunction(func) {
        const logger = this;
        return function () {
            logger.enterContext(func.name || 'anonymous');
            const result = func.apply(this, arguments);
            logger.exitContext();
            return result;
        };
    }

    instrumentClassMethods(className) {
        const logger = this;
        const classObj = globalThis[className];
        if (classObj && typeof classObj === 'function' && classObj.prototype) {
            const proto = classObj.prototype;
            for (const methodName of Object.getOwnPropertyNames(proto)) {
                try {
                    const method = proto[methodName];
                    if (typeof method === 'function' &&
                        method !== Logger &&
                        method !== Logger.prototype.constructor &&
                        !Object.getOwnPropertyNames(Logger.prototype).includes(methodName)) {
                        proto[methodName] = logger.instrumentFunction(method);
                    }
                } catch (error) {
                    // Ignore methods that cannot be accessed due to security restrictions
                }
            }
        }
    }

    instrumentGlobalFunctions() {
        const logger = this;
        for (const functionName in globalThis) {
            try {
                const func = globalThis[functionName];
                if (typeof func === 'function' &&
                    func !== Logger &&
                    func !== Logger.prototype.constructor &&
                    !Object.getOwnPropertyNames(Logger.prototype).includes(functionName)) {
                    globalThis[functionName] = logger.instrumentFunction(func);
                }
            } catch (error) {
                // Ignore functions that cannot be accessed due to security restrictions
            }
        }
    }

    startLogging() {
        this.instrumentGlobalFunctions();
    }

    stopLogging() {
        // No need to restore original functions in this approach
        console.log("Logging stopped.");
    }
}

const logger = new Logger();

function subFunction() {
    logger.log('hi from sub');
    subSubFunction();
    logger.log('what\' up sub');
}

function subSubFunction() {
    logger.log('hi from subsub!!');
}

function main() {
    logger.log('hi from main');
    subFunction();
}

// Start logging before executing main function
logger.startLogging();
main();
logger.stopLogging();
