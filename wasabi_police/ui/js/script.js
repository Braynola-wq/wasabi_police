/*var mockData = {
    action: 'jailCounter',
    header: 'YOU ARE IN JAIL!',
    sentence: '4 Months Left',
    color: '#0390fc'
}*/

//window.postMessage(mockData);

const selectors = {
    // Speed Traps
    cameraFlash: '.camera-flash',

    // Camera Overlay
    cameraOverlay: '.camera-overlay',
    timeDisplay: '.time-display',
    cameraName: '.camera-info-text',
  
    // Jail
    jailCounter: '.jail-counter',
    jailCounterHeader: '.jail-counter .heading',
    jailCounterText: '.jail-counter .sentence'
};

function getElements() {
    const elements = {};
    for (const key in selectors) {
        elements[key] = document.querySelector(selectors[key]);
    }
    return elements;
}

function HandleCameraFlash(elements) {
    elements.cameraFlash.style.display = 'flex';
    elements.cameraFlash.style.opacity = '1';
    setTimeout(() => {
        elements.cameraFlash.style.opacity = '0';
        setTimeout(() => {
            elements.cameraFlash.style.display = 'none';
        }, 1000);
    }, 100);
}

let inPrison;
function HandlePrisonCounter(data, elements) {
    if (!inPrison && data.sentence) {

        elements.jailCounterHeader.textContent = data.header;
        elements.jailCounterText.textContent = data.sentence;
        elements.jailCounter.style.display = 'flex';

        ApplyGradientTextEffect(elements.jailCounterHeader, data.color || '#ff0000');

        anime({
            targets: elements.jailCounter,
            opacity: [0, 1],
            scale: [0.9, 1],
            duration: 300,
            easing: 'easeOutExpo'
        });

        inPrison = true
        return;

    } else if (inPrison && !data.sentence) {
        anime({
            targets: elements.jailCounter,
            opacity: [1, 0],
            scale: [1, 0.],
            duration: 300,
            easing: 'easeOutExpo',
            complete: () => {
                elements.jailCounter.style.display = 'none';
            }
        });
        inPrison = false;
        return;
    }
    if (!data.sentence) { return; }
    elements.jailCounterText.textContent = data.sentence
}


const ColorNameToHex = (color) => {
    const colors = {
        "aliceblue": "#f0f8ff",
        "antiquewhite": "#faebd7",
        "aqua": "#00ffff",
        "aquamarine": "#7fffd4",
        "azure": "#f0ffff",
        "beige": "#f5f5dc",
        "bisque": "#ffe4c4",
        "black": "#000000",
        "blanchedalmond": "#ffebcd",
        "blue": "#0000ff",
        "blueviolet": "#8a2be2",
        "brown": "#a52a2a",
        "burlywood": "#deb887",
        "cadetblue": "#5f9ea0",
        "chartreuse": "#7fff00",
        "chocolate": "#d2691e",
        "coral": "#ff7f50",
        "cornflowerblue": "#6495ed",
        "cornsilk": "#fff8dc",
        "crimson": "#dc143c",
        "cyan": "#00ffff",
        "darkblue": "#00008b",
        "darkcyan": "#008b8b",
        "darkgoldenrod": "#b8860b",
        "darkgray": "#a9a9a9",
        "darkgreen": "#006400",
        "darkkhaki": "#bdb76b",
        "darkmagenta": "#8b008b",
        "darkolivegreen": "#556b2f",
        "darkorange": "#ff8c00",
        "darkorchid": "#9932cc",
        "darkred": "#8b0000",
        "darksalmon": "#e9967a",
        "darkseagreen": "#8fbc8f",
        "darkslateblue": "#483d8b",
        "darkslategray": "#2f4f4f",
        "darkturquoise": "#00ced1",
        "darkviolet": "#9400d3",
        "deeppink": "#ff1493",
        "deepskyblue": "#00bfff",
        "dimgray": "#696969",
        "dodgerblue": "#1e90ff",
        "firebrick": "#b22222",
        "floralwhite": "#fffaf0",
        "forestgreen": "#228b22",
        "fuchsia": "#ff00ff",
        "gainsboro": "#dcdcdc",
        "ghostwhite": "#f8f8ff",
        "gold": "#ffd700",
        "goldenrod": "#daa520",
        "gray": "#808080",
        "green": "#008000",
        "greenyellow": "#adff2f",
        "honeydew": "#f0fff0",
        "hotpink": "#ff69b4",
        "indianred": "#cd5c5c",
        "indigo": "#4b0082",
        "ivory": "#fffff0",
        "khaki": "#f0e68c",
        "lavender": "#e6e6fa",
        "lavenderblush": "#fff0f5",
        "lawngreen": "#7cfc00",
        "lemonchiffon": "#fffacd",
        "lightblue": "#add8e6",
        "lightcoral": "#f08080",
        "lightcyan": "#e0ffff",
        "lightgoldenrodyellow": "#fafad2",
        "lightgray": "#d3d3d3",
        "lightgreen": "#90ee90",
        "lightpink": "#ffb6c1",
        "lightsalmon": "#ffa07a",
        "lightseagreen": "#20b2aa",
        "lightskyblue": "#87cefa",
        "lightslategray": "#778899",
        "lightsteelblue": "#b0c4de",
        "lightyellow": "#ffffe0",
        "lime": "#00ff00",
        "limegreen": "#32cd32",
        "linen": "#faf0e6",
        "magenta": "#ff00ff",
        "maroon": "#800000",
        "mediumaquamarine": "#66cdaa",
        "mediumblue": "#0000cd",
        "mediumorchid": "#ba55d3",
        "mediumpurple": "#9370db",
        "mediumseagreen": "#3cb371",
        "mediumslateblue": "#7b68ee",
        "mediumspringgreen": "#00fa9a",
        "mediumturquoise": "#48d1cc",
        "mediumvioletred": "#c71585",
        "midnightblue": "#191970",
        "mintcream": "#f5fffa",
        "mistyrose": "#ffe4e1",
        "moccasin": "#ffe4b5",
        "navajowhite": "#ffdead",
        "navy": "#000080",
        "oldlace": "#fdf5e6",
        "olive": "#808000",
        "olivedrab": "#6b8e23",
        "orange": "#ffa500",
        "orangered": "#ff4500",
        "orchid": "#da70d6",
        "palegoldenrod": "#eee8aa",
        "palegreen": "#98fb98",
        "paleturquoise": "#afeeee",
        "palevioletred": "#db7093",
        "papayawhip": "#ffefd5",
        "peachpuff": "#ffdab9",
        "peru": "#cd853f",
        "pink": "#ffc0cb",
        "plum": "#dda0dd",
        "powderblue": "#b0e0e6",
        "purple": "#800080",
        "rebeccapurple": "#663399",
        "red": "#ff0000",
        "rosybrown": "#bc8f8f",
        "royalblue": "#4169e1",
        "saddlebrown": "#8b4513",
        "salmon": "#fa8072",
        "sandybrown": "#f4a460",
        "seagreen": "#2e8b57",
        "seashell": "#fff5ee",
        "sienna": "#a0522d",
        "silver": "#c0c0c0",
        "skyblue": "#87ceeb",
        "slateblue": "#6a5acd",
        "slategray": "#708090",
        "snow": "#fffafa",
        "springgreen": "#00ff7f",
        "steelblue": "#4682b4",
        "tan": "#d2b48c",
        "teal": "#008080",
        "thistle": "#d8bfd8",
        "tomato": "#ff6347",
        "turquoise": "#40e0d0",
        "violet": "#ee82ee",
        "wheat": "#f5deb3",
        "white": "#ffffff",
        "whitesmoke": "#f5f5f5",
        "yellow": "#ffff00",
        "yellowgreen": "#9acd32"
    };
    return colors[color.toLowerCase()] || color;
};


const ApplyGradientTextEffect = (element, color) => {

    if (!color.startsWith('#')) {
        color = ColorNameToHex(color);
    }

    const hexColor = color.slice(1);
    const r = parseInt(hexColor.substr(0, 2), 16);
    const g = parseInt(hexColor.substr(2, 2), 16);
    const b = parseInt(hexColor.substr(4, 2), 16);

    const lighterColor = `rgba(${r}, ${g}, ${b}, 0.5)`;
    const darkerColor = `rgba(${Math.max(r - 30, 0)}, ${Math.max(g - 30, 0)}, ${Math.max(b - 30, 0)}, 1)`;

    element.style.background = `linear-gradient(to right, ${lighterColor} 0%, ${darkerColor} 50%, ${lighterColor} 100%)`;
    element.style.textShadow = `0 0 2px rgba(${r}, ${g}, ${b}, 0.8), 
                                0 0 4px rgba(${r}, ${g}, ${b}, 0.6), 
                                0 0 6px rgba(${r}, ${g}, ${b}, 0.4)`;

    element.style.webkitTextFillColor = 'transparent';
    element.style.webkitBackgroundClip = 'text';
    element.style.backgroundClip = 'text';
}




// MAIN LISTENER
let mainListener;

if (mainListener) {
    window.removeEventListener('message', mainListener);
}

mainListener = (event) => {
        const data = event.data;
        const elements = getElements();

        if (data.action === 'cameraFlash') {
            HandleCameraFlash(elements);
            return;
        }

        if (data.action === 'showCamera') {
            elements.timeDisplay.textContent = data.time;
            elements.cameraName.textContent = data.name;
            elements.cameraOverlay.style.display = 'flex';
            return;
        }

        if (data.action === 'updateCameraTime') {
            elements.timeDisplay.textContent = data.time;
            return;
        }

        if (data.action === 'disableCameraOverlay') {
            // Hide the camera UI
            elements.cameraOverlay.style.display = 'none';
            return;
        }

        if (data.action === 'jailCounter') {
            HandlePrisonCounter(data, elements);
            return;
        }
};

window.addEventListener('message', mainListener);