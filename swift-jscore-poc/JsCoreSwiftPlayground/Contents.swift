import JavaScriptCore

// A series of tests to review how JSCore functions can be used with Swift.

// Simple Hello World, let's talk to Swift.
print ("Example 1: Hello World")
// Js Context Class
let context: JSContext = JSContext()
// Simple Hello World Example
let result1: JSValue = context.evaluateScript("'Hello Javascript'")
// Show output
print (result1)

// Test a simple function defined within this file.
print ("Example 2: Function")
// Js Context Class
let context2: JSContext = JSContext()
// Simple Trigger of function Example
context2.evaluateScript("function sum(param1, param2) { return param1 + param2; }")
// js method name by calling the method
let result2 = context2.evaluateScript("sum(22, 10)")
// Show output
print (result2 as Any)

// Reading from a custom JS file as you would within a traditional clientside website
print ("Example 3: Read from Js File")
// Js Context Class
let context3: JSContext = JSContext()
// js method name by calling the method
let fileLocation = Bundle.main.path(forResource: "index", ofType: "js")!
// file location
print(fileLocation)
let jsSource : String
  do {
    jsSource = try String(contentsOfFile: fileLocation)
  } catch {
    jsSource = "Nope."
  }
// eval script
context3.evaluateScript(jsSource)
// Trigger function
let functionFullname = context3.objectForKeyedSubscript("getFullname")
// With parameters
let result3 = functionFullname?.call(withArguments: ["Will", "I AM"])
// Show output
print(result3 as Any)

// Reading from loDash constant value from the library.
print ("Example 4: Read from Js File Library Value")
// Js Context Class
let context4: JSContext = JSContext()
// Simple Trigger of function Example
let fileLocationLib = Bundle.main.path(forResource: "loDash", ofType: "js")!
// file location
print(fileLocationLib)
let jsSourceLib : String
  do {
    jsSourceLib = try String(contentsOfFile: fileLocationLib)
  } catch {
    jsSourceLib = "Nope."
  }
// eval script
context4.evaluateScript(jsSourceLib)
// Read Constant variable
let result4: JSValue = context4.evaluateScript("LARGE_ARRAY_SIZE")
// Show output
print((result4 as Any))

// Read from non minified Js File Library Function of LoDash
print ("Example 5: Read from Js File Library Function")
// Js Context Class
let context5: JSContext = JSContext()
// Simple Trigger of function Example
let fileLocationLibFunc = Bundle.main.path(forResource: "loDash", ofType: "js")!
// file location
print(fileLocationLibFunc)
let jsSourceLibFunc : String
  do {
    jsSourceLibFunc = try String(contentsOfFile: fileLocationLibFunc)
  } catch {
    jsSourceLibFunc = "Nope."
  }
// eval script
context5.evaluateScript(jsSourceLibFunc)
// Trigger the function isLength("STRING")
let loDash = context5.objectForKeyedSubscript("isLength")
// Send Parameters
let result5 = loDash?.call(withArguments: ["Testing"])
// Outputs the result
print((result5 as Any))

// Read from Js Minified Library Function of LoDash
print ("Example 6: Read from Js File Minified Library Function")
// Js Context Class
let context6: JSContext = JSContext()
// Simple Trigger of function Example
let fileLocationLibFuncMin = Bundle.main.path(forResource: "loDash.min", ofType: "js")!
// file location
print(fileLocationLibFuncMin)
let jsSourceLibFuncMin : String
  do {
    jsSourceLibFuncMin = try String(contentsOfFile: fileLocationLibFuncMin)
  } catch {
    jsSourceLibFuncMin = "Could not load the loDash Min library. Ensure it has been added to the resources."
  }
// eval script
context6.evaluateScript(jsSourceLibFuncMin)
// Trigger the function isLength("STRING")
let loDashMin = context6.objectForKeyedSubscript("isLength")
// Send Parameters
let result6 = loDashMin?.call(withArguments: ["Testing"])
// Outputs the result
print((result6 as Any))

// Read from Node JS Crypto Module into Swift
print ("Example 7: Read from Node JS Crypto Module into Swift")
// Js Context Class
let context7: JSContext = JSContext()
// Shows that Swift can read from the Node JS Crypto Module.
let fileLocationLibMin = Bundle.main.path(forResource: "nodejs", ofType: "js")!
// file location
print(fileLocationLibMin)
let jsSourceLibMin : String
  do {
    jsSourceLibMin = try String(contentsOfFile: fileLocationLibMin)
  } catch {
    jsSourceLibMin = "Could not load the JS contents of Node Crypto Module. Ensure it has been added to the resources"
  }
// eval script
context7.evaluateScript(jsSourceLibMin)
// read from the script, like you would a node js application / javascript on the client.
let result7: JSValue = context7.evaluateScript("nodejs.crytpo.Cipher.toString()")
print((result7 as Any))






