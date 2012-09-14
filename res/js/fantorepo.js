
function flash(message, color) {
    $('#flash').html(message);
    $('#flash').css("background-color", color);
    $('#flash').slideDown('medium');
};

$(".confirmit").on("click", function(){
    console.debug(this);
    if( ! confirm(this.title)){
        event.preventDefault(); 
    }
});
    
$("#register").submit(function(){
    $.ajax( {
        type: "POST",
        url: $("#register").attr( 'action' ),
        data: $("#register").serialize(),
        success: function(  ) {
            $(location).attr('href','/');
        },
        error: function( resp ) {
            flash(resp.responseText, "#FFCCFF")
        }
    } ); 
    return false;
});

$("#login").submit(function(){
    $.ajax( {
        type: "POST",
        url: $("#login").attr( 'action' ),
        data: $("#login").serialize(),
        success: function(  ) {
            $(location).attr('href','/mypods');
        },
        error: function( resp ) {
            flash(resp.responseText, "#FFCCFF")
        }
    } ); 
    return false;
});

