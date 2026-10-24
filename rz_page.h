/* Wygenerowane: strona wysyłania pliku, serwowana przez telefon (polski, angielski, rosyjski). */
static const char RZ_PAGE[] =
    "<!DOCTYPE html><html lang=\"pl\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Rozkład: wyślij plik</title>\n"
    "<style>body{margin:0;font:16px/1.4 Helvetica,Arial,sans-serif;color:#2b2b2b;background:#eee6d3}\n"
    "h1{margin:0;padding:16px;text-align:center;font-size:22px;color:#f6ecd8;text-shadow:0 -1px 0 #000;background:linear-gradient(#7d5434,#4a2e1a);border-bottom:1px solid #22120a}\n"
    ".w{max-width:560px;margin:0 auto;padding:16px}.c{padding:14px;background:#fff;border:1px solid #a29e90;border-radius:10px}\n"
    "button{width:100%;margin-top:12px;padding:13px;font:bold 17px Helvetica,Arial,sans-serif;color:#fff;border:1px solid #6d0715;border-radius:10px;background:linear-gradient(#e8505f,#a60f25);cursor:pointer}\n"
    "button:disabled{background:#999;border-color:#777}#m{margin-top:12px;font-weight:bold}</style></head><body>\n"
    "<h1>Rozkład: wyślij plik na telefon</h1><div class=\"w\"><div class=\"c\"><p>Wybierz plik <b>rozklad.json</b> z generatora i kliknij przycisk.</p>\n"
    "<input type=\"file\" id=\"f\" accept=\".json,application/json\"><button id=\"b\" disabled>Wyślij na telefon</button><div id=\"m\"></div></div></div>\n"
    "<script>var f=document.getElementById('f'),b=document.getElementById('b'),m=document.getElementById('m');\n"
    "f.onchange=function(){b.disabled=!f.files.length;m.textContent=''};\n"
    "b.onclick=function(){var r=new FileReader();b.disabled=true;m.textContent='Wysyłam…';\n"
    "r.onload=function(){var x=new XMLHttpRequest();x.open('POST','/upload');x.setRequestHeader('Content-Type','text/plain');\n"
    "x.onload=function(){m.textContent=x.responseText;b.disabled=false};x.onerror=function(){m.textContent='Nie udało się połączyć z telefonem.';b.disabled=false};x.send(r.result)};\n"
    "r.readAsText(f.files[0])};</script></body></html>\n";

static const char RZ_PAGE_EN[] =
    "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Rozkład: send a file</title>\n"
    "<style>body{margin:0;font:16px/1.4 Helvetica,Arial,sans-serif;color:#2b2b2b;background:#eee6d3}\n"
    "h1{margin:0;padding:16px;text-align:center;font-size:22px;color:#f6ecd8;text-shadow:0 -1px 0 #000;background:linear-gradient(#7d5434,#4a2e1a);border-bottom:1px solid #22120a}\n"
    ".w{max-width:560px;margin:0 auto;padding:16px}.c{padding:14px;background:#fff;border:1px solid #a29e90;border-radius:10px}\n"
    "button{width:100%;margin-top:12px;padding:13px;font:bold 17px Helvetica,Arial,sans-serif;color:#fff;border:1px solid #6d0715;border-radius:10px;background:linear-gradient(#e8505f,#a60f25);cursor:pointer}\n"
    "button:disabled{background:#999;border-color:#777}#m{margin-top:12px;font-weight:bold}</style></head><body>\n"
    "<h1>Rozkład: send a file to the phone</h1><div class=\"w\"><div class=\"c\"><p>Choose the <b>rozklad.json</b> file from the generator and click the button.</p>\n"
    "<input type=\"file\" id=\"f\" accept=\".json,application/json\"><button id=\"b\" disabled>Send to phone</button><div id=\"m\"></div></div></div>\n"
    "<script>var f=document.getElementById('f'),b=document.getElementById('b'),m=document.getElementById('m');\n"
    "f.onchange=function(){b.disabled=!f.files.length;m.textContent=''};\n"
    "b.onclick=function(){var r=new FileReader();b.disabled=true;m.textContent='Sending…';\n"
    "r.onload=function(){var x=new XMLHttpRequest();x.open('POST','/upload');x.setRequestHeader('Content-Type','text/plain');\n"
    "x.onload=function(){m.textContent=x.responseText;b.disabled=false};x.onerror=function(){m.textContent='Could not connect to the phone.';b.disabled=false};x.send(r.result)};\n"
    "r.readAsText(f.files[0])};</script></body></html>\n";

static const char RZ_PAGE_RU[] =
    "<!DOCTYPE html><html lang=\"ru\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Rozkład: отправить файл</title>\n"
    "<style>body{margin:0;font:16px/1.4 Helvetica,Arial,sans-serif;color:#2b2b2b;background:#eee6d3}\n"
    "h1{margin:0;padding:16px;text-align:center;font-size:22px;color:#f6ecd8;text-shadow:0 -1px 0 #000;background:linear-gradient(#7d5434,#4a2e1a);border-bottom:1px solid #22120a}\n"
    ".w{max-width:560px;margin:0 auto;padding:16px}.c{padding:14px;background:#fff;border:1px solid #a29e90;border-radius:10px}\n"
    "button{width:100%;margin-top:12px;padding:13px;font:bold 17px Helvetica,Arial,sans-serif;color:#fff;border:1px solid #6d0715;border-radius:10px;background:linear-gradient(#e8505f,#a60f25);cursor:pointer}\n"
    "button:disabled{background:#999;border-color:#777}#m{margin-top:12px;font-weight:bold}</style></head><body>\n"
    "<h1>Rozkład: отправить файл на телефон</h1><div class=\"w\"><div class=\"c\"><p>Выберите файл <b>rozklad.json</b> из генератора и нажмите кнопку.</p>\n"
    "<input type=\"file\" id=\"f\" accept=\".json,application/json\"><button id=\"b\" disabled>Отправить на телефон</button><div id=\"m\"></div></div></div>\n"
    "<script>var f=document.getElementById('f'),b=document.getElementById('b'),m=document.getElementById('m');\n"
    "f.onchange=function(){b.disabled=!f.files.length;m.textContent=''};\n"
    "b.onclick=function(){var r=new FileReader();b.disabled=true;m.textContent='Отправляю…';\n"
    "r.onload=function(){var x=new XMLHttpRequest();x.open('POST','/upload');x.setRequestHeader('Content-Type','text/plain');\n"
    "x.onload=function(){m.textContent=x.responseText;b.disabled=false};x.onerror=function(){m.textContent='Не удалось подключиться к телефону.';b.disabled=false};x.send(r.result)};\n"
    "r.readAsText(f.files[0])};</script></body></html>\n";
