// Create src buttons
function addButton(name, idx) {
    //Create an input type dynamically.   
    var element = document.createElement("button");
    element.textContent= name;
    element.classList.add("srcButton");              
    element.setAttribute("_buttonIdx", idx);
    element.onclick = function() {
        let buttonIdx = this.getAttribute("_buttonIdx");
        if (collapsibles[buttonIdx].style.display == "none"){
            collapsibles[buttonIdx].style.display = "block";
        }
        else {
            collapsibles[buttonIdx].style.display = "none";
        }
    }; 
    return element;
}

// Create collapsible buttons
var collapsibles = document.getElementsByClassName("src_explore_collapsible");
for (let i = 0; i < collapsibles.length; i++) {
    const elem = collapsibles[i];
    
    var srcName = "";
    let codeSrc = collapsibles[i].getElementsByTagName("CODE")[0];
    
    srcName = codeSrc.dataset.src; 
    const cutIdx = srcName.lastIndexOf("/");
    if (cutIdx != -1) {
        srcName = srcName.substring(cutIdx + 1);
    }

    let button = addButton(srcName, i);  

    var foo = document.getElementsByClassName("src_explore_collapsible")[i];  
    foo.before(button)
}

// Close all src (collapsibles)
var collapsibles = document.getElementsByClassName("src_explore_collapsible");
for (let i = 0; i < collapsibles.length; i++) {
    const elem = collapsibles[i];
    elem.style.display = "none";
}

// Rename the path
// Take random src
var pathName = collapsibles[0].getElementsByTagName("CODE")[0].dataset.src;
// Take the path
var cutIdx = pathName.lastIndexOf("/");
pathName = pathName.substring(0, cutIdx);
// Remove "sources" folder from path
cutIdx = pathName.indexOf("/",1);
pathName = "/" + pathName.substring(cutIdx + 1);

document.getElementsByClassName("src_explore_path")[0]
    .textContent = pathName;
