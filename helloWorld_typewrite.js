var i = 0;
var text1 = "Hello World!";
var text2 = "48 65 6c 6c 6f 20 77 6f 72 6c 64 21"; 
var speed = 170; 
var first_time = true;

function typeWriter_DelayedStart(){
    var elem          = document.getElementById("TypeWriter_HelloWorld");
    var hex_pair_elem = document.getElementById("TypeWriter_hexpair");
    if (elem != null) {
        setTimeout(typeWriter, 300);
    }
}

function typeWriter() {
    
    var elem          = document.getElementById("TypeWriter_HelloWorld");
    var hex_pair_elem = document.getElementById("TypeWriter_hexpair");

    if (first_time == true) {
        elem.innerHTML = "";
        hex_pair_elem.innerHTML = "";
        first_time = false;
    }

    if (elem != null) {
        if (i < text1.length) {
            elem.innerHTML += text1.charAt(i);
            for (let j = 0; j < 3; j++) {
                hex_pair_elem.innerHTML += text2.charAt(j + i*3);
            }
            i++;
            setTimeout(typeWriter, speed);
        }
    }
}



window.addEventListener('load', (event) => {
    typeWriter_DelayedStart();
});
