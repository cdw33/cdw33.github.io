//
//  BonsaiXML
//
//  Copyright © 2015 Christopher Wilson. https://github.com/cdw33
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import UIKit

/**
* The BonsaiParser class includes the XML Parser and DOM builder. It includes the functionality
* to get local and external (web) XML files. After accessing the XML file, it is parsed and
* a DOM tree is built in real time.
**/
class BonsaiParser{
    
    var parserStack = Stack<Element>()
    
    var bDoc = BonsaiDocument()
    
    init(readFromURL url:String) {
        //Get XML File from Web Server and store contents in String
        let xmlUrl = NSURL(string: url)!
        let xmlString = downloadXml(xmlUrl)
        
        parse(xmlString!)
    }
    
    init(readFromURL url:NSURL) {
        //Get XML File from Web Server and store contents in String
        let xmlString = downloadXml(url)
        
        parse(xmlString!)
    }
    
    init(readLocalFile path:String){
        let xmlString = getXmlDataStringFromFile(path)
        
        parse(xmlString!)
    }
    
    deinit{
        //print("Deallocating BonsaiParser")
    }
    
    //Get XML file with the given filename from local storage
    func getXmlDataStringFromFile(filename:String!)->String?{
        
        return ""
    }
    
    //Download the XML file from the given URL as NSURL
    func downloadXml(url:NSURL!)->String?{
        do{
            return try String(contentsOfURL: url, encoding: NSUTF8StringEncoding)
        }
        catch{
            throwError("XML_URL")
            return nil
        }
    }
    
    //Start XML parsing routine. DOM tree is built in real time as the XML file is being parsed.
    func parse(xmlStr:String){
        
        let xmlArr = convertXmlStringToArray(xmlStr)
        
        buildDomTree(xmlArr)
        
    }
    
    
    /* Convert a given XML file string to a 2D array of Tags and Values. Any attributes are kept within the
    opening tag and are parsed out later. An example out the file input and output is below
    
    input:
    <Parent name="John">\n
    \t<Child>Child 1</Child>\n
    \t<Child>Child 2</Child>\n
    </Parent>
    
    output:
    ["Parent name="John""],
    ["Child", "Child 1", "/Child"],
    ["Child", "Child 2", "/Child"],
    ["/Parent"]
    
    */
    func convertXmlStringToArray(xmlStr:String)->[[String]]{ //TODO - This can probably be refactored to reduce processing time
        //Convert XML data to array by splitting on newline characters
        var tmpArr = xmlStr.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        
        var xmlArr = [[String]]() //stores each line of tmpArr, split into array on whitespace chars
        
        
        for line in tmpArr{
            let index = tmpArr.indexOf(line)
            
            if(tmpArr[index!] == ""){ //blanks
                tmpArr.removeAtIndex(index!)
            }
            else{ //remove leading whitespace
                let cleanStr = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                tmpArr[tmpArr.indexOf(line)!] = cleanStr
                
                //Split up line based on defined character set
                let separators = NSCharacterSet(charactersInString: "<,>")
                var lineArr = line.componentsSeparatedByCharactersInSet(separators)
                
                //Remove Excess Whitespace
                lineArr.removeFirst()
                lineArr.removeLast()
                
                //Add line array to xml array
                xmlArr.append(lineArr)
            }
        }
        
        return xmlArr
    }
    
    //Top level DOM builder function, XML entries are converted into nodes and proccessed accordingly
    func buildDomTree(xmlArr:[[String]]){
        var tmpNode:Element!
        //for each line in xml array
        for lineArr in xmlArr{
            
            //Ignore Comments and Declarations
            let tmpChar = lineArr.first?.characters.first
            if(tmpChar != "?" && tmpChar != "!"){
                
                //convert line to node
                tmpNode = buildNodeFromLine(lineArr)
                
                if(tmpNode == nil){ //line was a closing tag
                    processClosingTag(lineArr.first!)
                }
                else{ //node is xml data
                    if(tmpNode.getState() == .CLOSED){ //if node is complete (opening & closing tag on same line)
                        processCompleteTag(tmpNode)
                    }
                    else{ //node is opening node
                        processOpeningTag(tmpNode)
                    }
                    
                }
            }
        }
    }
    
    //A complete tag is an XML entry which has its opening and closing tags on the same line
    //ex. <Child>Child 1</Child>
    func processCompleteTag(tmpNode:Element){
        if(parserStack.isEmpty() == false){ //if stack is not empty
            if(parserStack.peek().getFirstChild() == nil){ //if top of stack has no children
                bDoc.appendNodeAsFirstChild(parserStack.peek(), childNode: tmpNode)
            }
            else{ //else - top of stack has child
                bDoc.appendNodeAsLastSibling(parserStack.peek(), childNode: tmpNode)
            }
        }
        else{//else - stack is empty
            if(bDoc.getRootNode().getChildCount() == 0){
                bDoc.appendNodeAsFirstChild(bDoc.getRootNode(), childNode: tmpNode)
            }
            else{ //else - root node has child
                bDoc.appendNodeAsLastSibling(bDoc.getRootNode(), childNode: tmpNode)
            }
        }
        
        tmpNode.setState(.CLOSED) //set state to closed
    }
    
    //An opening tag is an XML entry that has its opening tag on a single line.
    //ex. <Parent>
    func processOpeningTag(tmpNode:Element){
        if(parserStack.isEmpty() == false){
            if(parserStack.peek().getFirstChild() == nil){
                bDoc.appendNodeAsFirstChild(parserStack.peek(), childNode: tmpNode)
            }
            else{ //top of stack has child
                bDoc.appendNodeAsLastSibling(parserStack.peek(), childNode: tmpNode)
            }
        }
        else{//stack is empty
            if(bDoc.getRootNode().getChildCount() == 0){ //if root node has no children
                bDoc.appendNodeAsFirstChild(bDoc.getRootNode(), childNode: tmpNode)
            }
            else{ //root node has child
                bDoc.appendNodeAsLastSibling(bDoc.getRootNode(), childNode: tmpNode)
            }
        }
        
        parserStack.push(tmpNode) //push node onto Stack
    }
    
    //An closing tag is an XML entry that has its closing tag on a single line.
    //ex. </Parent>
    func processClosingTag(tag:String){
        if(parserStack.isEmpty() == true){ //if stack is empty
            
        }
        else{ //Stack has node
            if(parserStack.peek() != nil){
                let stackTag = parserStack.peek().getTag()
                
                let closingTag = String(tag.characters.dropFirst()) //remove leading "/" from closing tag
                
                if(closingTag == stackTag){ //if node matches top of stack
                    parserStack.peek().setState(.CLOSED) //set state to closed
                    parserStack.pop()
                }
                else{
                    throwError("INVALID_XML")
                }
            }
            else{
                throwError("INVALID_XML")
            }
        }
    }
    
    //This function takes an XML line, split on it angle brackets, as an array and builds a node object
    //from it. If it is passed an opening tag with attributes, it handles them accordingly
    func buildNodeFromLine(lineArr:[String])->Element?{
        let tmpNode = Element()
        
        if(lineArr.count == 1){ //Check if line is a single tag
            
            //Get item tag type and handle accordingly
            switch(getTagType(lineArr.first!)){
                
            case TagType.START:
                //break up line on attributes, if they exist
                var lineStr:[String] = "\(lineArr)".componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                
                //set tag - removing erroneous characters
                let separators = NSCharacterSet(charactersInString: "[,],\"")
                let tmpStr = lineStr.first!.stringByTrimmingCharactersInSet(separators)
                tmpNode.setTag(tmpStr)
                
                if(lineStr.count > 1){ //Process attributes if available
                    lineStr.removeFirst()
                    
                    processAttributes(lineStr, xmlNode: tmpNode)
                }
                
                break
                
            case TagType.END:
                return nil
                
            case TagType.EMPTY:
                //TODO - Handle empty-element tags (eg. <line-break />)
                break
            }
        }
        else{
            //Store value if one exists
            if(lineArr.count == 3){
                tmpNode.setValue(lineArr[lineArr.startIndex.advancedBy(1)])
            }
            
            let tmpTag = lineArr[lineArr.startIndex]
            
            //break up tag on attributes, if they exist
            var lineStr:[String] = tmpTag.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            
            tmpNode.setTag(lineStr[lineStr.startIndex]) //Set Element tag
            
            if(lineStr.count > 1){ //Process attributes if available
                lineStr.removeFirst() //remove tag
                
                processAttributes(lineStr, xmlNode: tmpNode)
            }
            
            //Check if item is properly closed, if not, throw error
            let endTag = String(lineArr.last!.characters.dropFirst()) //remove leading "/" from end tag
            
            if(tmpNode.getTag() == endTag){
                tmpNode.setState(.CLOSED) //mark as properly closed
            }
            else{
                throwError("INVALID_XML")
            }
        }
        
        return tmpNode
    }
    
    enum TagType{
        case START, END, EMPTY
    }
    
    //Returns type of given tag. Possible types are start-tags, end-tags, and empty-element tags
    func getTagType(tag:String)->TagType{
        if(tag.characters.first == "/"){
            return TagType.END
        }
        else if(tag.characters.last == "/"){
            return TagType.EMPTY
        }
        else{
            return TagType.START
        }
    }
    
    //Given an XML line as an array, this function parses out the attributes and stores them in
    //the given nodes Atrributes dictionary
    func processAttributes(xmlStr:[String], xmlNode:Element){
        for item in xmlStr{
            
            //Split attribute tag on "="
            var attrArr = "\(item)".componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "="))
            
            //clean attribute value
            let separators = NSCharacterSet(charactersInString: "\\,\",]")
            let cleanStr = attrArr.last!.stringByTrimmingCharactersInSet(separators)
            
            //Replace value with cleanStr
            attrArr.removeLast()
            attrArr.append(cleanStr)
            
            xmlNode.addAttribute(attrArr.last!, key: attrArr.first!)
        }
    }
    
    //Returns a reference to a BonsaiNode which points to the first XML node
    func getRootElement()->BonsaiElement{
        return BonsaiElement(node: bDoc.getRootNode())
    }
    
    func throwError(id:String){
        switch(id){
        case "INVALID_XML":
            print("XML File is Invalid")
            break
        case "XML_URL":
            print("Unable to retrieve XML file")
            break
        default:
            break
        }
    }
}

/**
* This class works like an extension to the Element class in BonsaiXML. It provides
* functions to ease the process of traversing through a DOM tree and prevents the
* user accidentally accessing a nil pointer (eg. calling nextSibling on a leaf node)
**/
class BonsaiElement{
    private var node:Element!
    
    let ROOT_ID = "ROOT"
    
    init(node:Element){
        self.node = node
    }
    
    deinit{
        //print("Deallocating Bonasi Element")
    }
    
    //Traversal Functions
    
    func firstChild(){
        if(node.getFirstChild() != nil){
            node = node.getFirstChild()
        }
    }
    
    func nextSibling(){
        if(node.getNextSibling() != nil){
            node = node.getNextSibling()
        }
    }
    
    func previousSibling(){
        if(node.getPreviousSibling() != nil){
            node = node.getPreviousSibling()
        }
    }
    
    func parent(){
        if(node.getParent().getTag() != ROOT_ID){
            node = node.getParent()
        }
    }
    
    func root(){
        while(node.getParent().getTag() != ROOT_ID){
            node = node.getParent()
        }
    }
    
    //Read Functions
    
    func getTag()->String{
        return node.getTag()
    }
    
    func getValue()->String{
        return node.getValue()
    }
    
    func getAttributeByName(name:String)->String!{
        for attr in node.attributes{
            if(attr.0 == name){
                return attr.1
            }
        }
        return nil
    }
    
    //Write Functions
    
    func setValue(value:String){
        node.setValue(value)
    }
    
    func setAttributeByName(newValue:String, key:String){
        node.addAttribute(newValue, key: key)
    }
    
    func getAttributes()->[String: String]{
        return node.attributes
    }
}

//Stores Open/Closed state of Node Tags
enum State{
    case OPEN, CLOSED
}

/**
* Each Element object contains a single XML item, including its name, type, value,
* attributes, etc. It also includes references to parent, child, and sibling elements.
* All member variables are private and can only be accessed by getter and setter functions.
**/
class Element {
    
    //Element Properties
    private var tag = ""
    private var value = ""
    private var attributes = [String: String]()
    private var numChildren = 0
    private var state = State.OPEN //Closed when closing brackets have been reached
    
    //Element References
    private var firstChild:Element!
    private var previousSibling:Element!
    private var nextSibling:Element!
    private var parent:Element!
    
    //Initializers
    init(){
    }
    
    init(tag:String){
        self.tag = tag
    }
    
    //Getter & Setter Functions
    func getTag()->String{return tag}
    func setTag(tag:String){self.tag = tag}
    
    func getValue()->String{return value}
    func setValue(value:String){self.value = value}
    
    func setState(state:State){self.state = state}
    func getState()->State{return state}
    
    func getChildCount()->Int{return numChildren}
    func incrementChildCount(){numChildren++}
    func decrementChildCount(){numChildren--}
    
    func setFirstChild(node:Element){firstChild = node}
    func setNextSibling(node:Element){nextSibling = node}
    func setPreviousSibling(node:Element){previousSibling = node}
    func setParent(node:Element){parent = node}
    
    func getFirstChild()->Element?{return firstChild}
    func getNextSibling()->Element?{return nextSibling}
    func getPreviousSibling()->Element?{return previousSibling}
    func getParent()->Element{return parent}
    
    func addAttribute(value:String, key:String){
        attributes.updateValue(value, forKey: key)
    }
}

/**
* This class builds and stores the DOM tree. When a new XML element is retrieved
* from the input file, it is passed into this class where it is appended to its
* respective position on the DOM tree. Its location is decided by the Parser.
**/
class BonsaiDocument{
    var rootNode:Element!
    
    let ROOT_ID = "ROOT"
    
    init(){
        rootNode = Element(tag: ROOT_ID)
    }
    
    //When it is determined that a node (childNode) should be the first child of another node
    //(parentNode), this function handles appending it to the DOM tree
    func appendNodeAsFirstChild(parentNode:Element, childNode:Element){
        parentNode.setFirstChild(childNode)  //set childNode as firstChild of parentNode
        parentNode.incrementChildCount() //increment child count
        
        childNode.setParent(parentNode) //set childNodes parent to parentNode
    }
    
    //When it is determined that a node (childNode) should be the child of another node (parentNode)
    //that already has at least one child, this function handles appending it to the DOM tree
    func appendNodeAsLastSibling(parentNode:Element, childNode:Element){
        var tmpNode = parentNode //temp node to find current last sibling
        
        //Find last sibling of given parentNode
        tmpNode = tmpNode.getFirstChild()!
        while(tmpNode.getNextSibling() != nil){
            tmpNode = tmpNode.getNextSibling()!
        }
        
        //node should now be pointing to last sibling of parentNode
        tmpNode.setNextSibling(childNode) //add childNode as nextSibling
        
        childNode.setPreviousSibling(tmpNode) //add parentNode as prevSibling
        
        parentNode.incrementChildCount() //increment parentNodes child count
        
        childNode.setParent(parentNode) //set childNodes parent to parentNode
    }
    
    //Returns a reference to a BonsaiNode which points to the first XML node
    func getRootNode()->Element{
        if(rootNode.getFirstChild() != nil){
            return rootNode.getFirstChild()!
        }
        else{
            return rootNode
        }
    }
}

/**
* This is a generic stack implementation
**/
class Stack<Element>{
    private var count: Int = 0
    private var head: StackNode<Element>!
    
    init() {
        head = nil
    }
    
    func isEmpty() -> Bool {
        return count == 0
    }
    
    func push(value: Element) {
        if isEmpty() {
            head = StackNode(value: value)
        }
        else {
            let node = StackNode(value: value)
            node.next = head
            head = node
        }
        
        count++
    }
    
    func pop() {
        if isEmpty() {
            return
        }
        
        let node = head
        head = node!.next
        count--
    }
    
    func peek() -> Element! {
        return head.item
    }
    
    func size()->Int{
        return count
    }
}

class StackNode<Element>{ //Made this a class because Swift does not allow recursive structs
    var item: Element!
    var next: StackNode<Element>?
    
    init(value: Element) {
        item = value
    }
}