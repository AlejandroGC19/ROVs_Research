function [datos_raw]=Representacion_PV_TR(Matriz_Datos,m)

global TimeText

datos_raw = Matriz_Datos(m, 25:1224);%+30;
    
for circ=300:300:1200
    if circ==1200
        datos_raw(circ-3)=0;datos_raw(circ-2)=0; datos_raw(circ-1)=0; datos_raw(circ)=0;datos_raw(1)=0;datos_raw(2)=0;datos_raw(3)=0;
    else
        datos_raw(circ-3)=0;datos_raw(circ-2)=0; datos_raw(circ-1)=0; datos_raw(circ)=0;datos_raw(circ+1)=0;datos_raw(circ+2)=0;datos_raw(circ+3)=0;
    end
end
datos_raw(1)=0;
datos_raw(end)=255;

TimeText.String=num2str(Matriz_Datos(m, 1),'%.1f');       
drawnow
end
