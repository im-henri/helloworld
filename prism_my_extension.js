document.addEventListener('DOMContentLoaded', (event) => {
    ext_src_insert();
});

function ext_src_insert(){

    var lst = document.getElementsByTagName("CODE");
    for (let i = 0; i < lst.length; i++) {
        const elem = lst[i];
        var src = elem.dataset.src;

        if (src) {
            var request = new XMLHttpRequest();
            request.open("GET", src, false);
            request.send(null);
            elem.innerHTML = request.responseText;
            
        }
    }
}