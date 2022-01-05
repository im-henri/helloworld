var cubeScene = null;
var cube3d    = null;
var cubeSceneOpacity = 1.0;

var back  = null; // img of cube face
var front = null; // img of cube face
var left  = null; // img of cube face
var right = null; // img of cube face
// var top = null;
// var down = null;

var scrollPercent = 0;
// min scroll percent to scroll up when cube is clicked
var min_click_scroll_up = 0.1;

var min_scroll  = 100;
var min_opacity = 0.3;

//var min_scale   = 0.9;

window.addEventListener('load', (event) => {
    initialize();
});

window.onscroll = function(e) {
    on_scroll(this.scrollY);
}

function initialize(){
    cubeScene = document.getElementsByClassName("cube3d_scene")[0];
    cube3d    = cubeScene.getElementsByClassName("cube3d")[0];

    back  = cube3d.getElementsByClassName("back")[0].getElementsByTagName("img")[0];
    front = cube3d.getElementsByClassName("front")[0].getElementsByTagName("img")[0];
    left  = cube3d.getElementsByClassName("left")[0].getElementsByTagName("img")[0];
    right = cube3d.getElementsByClassName("right")[0].getElementsByTagName("img")[0];
    //top   = cube3d.getElementsByClassName("top")[0].getElementsByTagName("img")[0];
    //down  = cube3d.getElementsByClassName("down")[0].getElementsByTagName("img")[0];
    
    cubeScene.addEventListener("mouseenter", function(){
        cubeScene.style.opacity = 1;
        if (scrollPercent > min_click_scroll_up){
            back.src  = "images/cubeUp.png";
            front.src = "images/cubeUp.png";
            left.src  = "images/cubeUp.png";
            right.src = "images/cubeUp.png";
            //top.src   = "images/cubeBack.png";
            //down.src  = "images/cubeBack.png";
        }
        else{
            back.src  = "images/cubeBack.png";
            front.src = "images/cubeBack.png";
            left.src  = "images/cubeBack.png";
            right.src = "images/cubeBack.png";
            //top.src   = "images/cubeBack.png";
            //down.src  = "images/cubeBack.png";
        }
    });
    cubeScene.addEventListener("mouseleave", function(){
        cubeScene.style.opacity = cubeSceneOpacity;
        back.src  = "images/cubeFace.png";
        front.src = "images/cubeFace.png";
        left.src  = "images/cubeFace.png";
        right.src = "images/cubeFace.png";
        //top.src   = "images/cubeFace.png";
        //down.src  = "images/cubeFace.png";
    });

    cubeScene.addEventListener("click", function(){
        on_cube_click();
    });
}
function on_scroll(value){
    if(cubeScene == null) return;
    
    if (value < min_scroll) {
        scrollPercent = value/min_scroll;
        cubeSceneOpacity  =  1.0-scrollPercent * (1.0 - min_opacity);
        //cubeScene.style.transform = "scale(" + String(1.0-(scrollPercent)*(1.0-min_scale)) +  ")";

    } else {
        cubeSceneOpacity = min_opacity;
        //cubeScene.style.transform = "scale(" + String(min_scale)+  ")";
    }
    cubeScene.style.opacity = cubeSceneOpacity;
}

function on_cube_click(){
    if (scrollPercent > min_click_scroll_up){
        window.scrollTo({top: 0, behavior: 'smooth'});
        back.src  = "images/cubeBack.png";
        front.src = "images/cubeBack.png";
        left.src  = "images/cubeBack.png";
        right.src = "images/cubeBack.png";
    }
    else{
        history.back();
    }
}