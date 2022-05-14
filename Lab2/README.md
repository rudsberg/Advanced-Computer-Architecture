
# Advanced-Computer-Architecture

## How to run it

The implementation is written in Swift. According to Louis Coulon, the grader will have installed swift through [here](https://www.swift.org/download/). 


The top level of the extracted zip file contains a file, `AllInOneFile.swift` and a folder `VLIW470`. The folder contains the project as it was created in Xcode, but to simplify for the grader (assuming Xcode is not installed), the `AllInOneFile.swift` contains all source code packaged into one file. **This is the file to run**. Here is an example run:

```
swift AllInOneFile.swift /Users/joelrudsberg/Desktop/submission/resources handout.json simple.json pip.json
```

The arguments represent: 
* the path to the folder where the program resides and where the log file will be saved
* the program file 
* the VLIW output file name for the *loop* instruction
* the VLIW output file name for the *loop.pip* instruction  

**The folder must be created before running**. 

The program prints each of the major components produced during execution: the parsed program, the dependency table,  the loop and pip schedule, the alloc_b and alloc_r register allocation, and the prepared loop for pip. 

## How to review the files
Review the files in the folder `VLIW470`, because here the code is separated into files. Or, perhaps even easier, through the [repository](https://github.com/rudsberg/Advanced-Computer-Architecture/tree/main/Lab2/VLIW470/VLIW470).
