local native=bit32 or bit
local floor=math.floor
local modulus=4294967296
local xor4={}
for a=0,15 do
    xor4[a]={}
    for b=0,15 do
        local x,y,value,place=a,b,0,1
        for _=1,4 do
            if x%2~=y%2 then value=value+place end
            x=floor(x/2);y=floor(y/2);place=place*2
        end
        xor4[a][b]=value
    end
end
local function bxor(a,b)
    if native then return native.bxor(a,b)%modulus end
    local value,place=0,1
    for _=1,8 do
        value=value+xor4[a%16][b%16]*place
        a=floor(a/16);b=floor(b/16);place=place*16
    end
    return value
end
local function band(a,b)
    if native then return native.band(a,b)%modulus end
    return (a+b-bxor(a,b))/2
end
local function rotate(a,n)
    return floor(a/2^n)+(a%2^n)*2^(32-n)
end
local function triple(a,b,c)return bxor(bxor(a,b),c)end
local constants={
    1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,
    3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,
    3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,
    2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,
    666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,
    2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,
    430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,
    1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298}
return function(message,pause)
    local length=#message
    local tail=string.char(128)..string.rep('\0',(55-length)%64)
    local bits=length*8
    for shift=7,0,-1 do tail=tail..string.char(floor(bits/256^shift)%256) end
    message=message..tail
    local h={1779033703,3144134277,1013904242,2773480762,1359893119,2600822924,528734635,1541459225}
    local w={}
    for start=1,#message,64 do
        for i=0,15 do local a,b,c,d=message:byte(start+i*4,start+i*4+3);w[i]=((a*256+b)*256+c)*256+d end
        for i=16,63 do
            local a,b=w[i-15],w[i-2]
            w[i]=(w[i-16]+triple(rotate(a,7),rotate(a,18),floor(a/8))+w[i-7]
                +triple(rotate(b,17),rotate(b,19),floor(b/1024)))%modulus
        end
        local a,b,c,d,e,f,g,k=unpack(h)
        for i=0,63 do
            local t1=(k+triple(rotate(e,6),rotate(e,11),rotate(e,25))
                +bxor(band(e,f),band(modulus-1-e,g))+constants[i+1]+w[i])%modulus
            local t2=(triple(rotate(a,2),rotate(a,13),rotate(a,22))
                +triple(band(a,b),band(a,c),band(b,c)))%modulus
            k=g;g=f;f=e;e=(d+t1)%modulus;d=c;c=b;b=a;a=(t1+t2)%modulus
        end
        local values={a,b,c,d,e,f,g,k}
        for i=1,8 do h[i]=(h[i]+values[i])%modulus end
        if pause then pause() end
    end
    local result={}
    for i=1,8 do result[i]=string.format('%08x',h[i]) end
    return table.concat(result)
end
