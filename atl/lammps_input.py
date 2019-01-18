"""
Reading/writing lammps input data file and using it in molframe class
"""
import datetime


def read_lammps_input(filename='lammps.lmp', attributes='Box Masses Atoms Bonds Angles Dihedrals Impropers Types'):
    """
    This function reads lammps input file in full atomic style.
    It includes box, masses, atoms, bonds, angles, dihedrals, impropers, and types attributes
    and return a dictionary.

    Example:

    data=read_lammps_input(fileName='grn.lmp')
    for k in data.keys():
        print k,len(data[k]) #, data[k][0]
    """

    data = {}
    for sec in attributes.split():

        # reading number of types for atoms, bonds, angles, dihedrals, and impropers
        if sec == 'Types':
            types_num = ['atom types', 'bond types', 'angle types', 'dihedral types', 'improper types']
            sectionData = [0, 0, 0, 0, 0]
            with open(filename, 'r') as infile:
                n_line = 0
                n_token = 0
                for line in infile:
                    n_line += 1
                    for keyword in types_num:
                        if keyword.split()[0] in line and keyword.split()[1] in line:
                            n_token += 1
                            ind = types_num.index(keyword)
                            tokens = line.split()[0]
                            sectionData[ind] = int(tokens)
                    if n_token==len(types_num) or n_line==100:
                        break

        # reading box sizes, tilted box data is also simply read
        elif sec == 'Box':
            sectionData = []
            with open(filename, 'r') as infile:
                n_line = 0
                for line in infile:

                    for lo, hi in zip(['xlo', 'ylo', 'zlo'], ['xhi', 'yhi', 'zhi']):
                        if lo in line and hi in line:
                            tokens = line.split()[:2]
                            sectionData.append([float(_) for _ in tokens])

                    if "xy xz yz" in line:
                        tokens = line.split()[:3]
                        sectionData.append([float(_) for _ in tokens])
                        # print 'Info: tilted box is read'

                    if len(sectionData) == 4 or n_line==100:
                        break

        # Reading Atoms, Bonds, Agngles, ect
        else:

            f = open(filename, 'r')
            sectionData = []

            line = f.readline()
            while not sec in line:
                line = f.readline()
                if not line:
                    break

            line = f.readline()
            prev = None
            tokens = None
            while True:
                line = f.readline()
                if not line:
                    break
                line = line[:line.find('#')]
                tokens = line.split()
                if prev == None:
                    prev = len(tokens)
                if prev != len(tokens):
                    break
                if sec == 'Atoms':
                    if len(tokens) == 7:
                        tokens = (line + ' 0 0 0 ' + tokens[2]).split()
                    elif len(tokens) == 10:
                        tokens = (line + ' ' + tokens[2]).split()
                    sectionData.append([int(tokens[0]), int(tokens[1]), int(tokens[2]),
                                        float(tokens[3]), float(tokens[4]), float(tokens[5]), float(tokens[6]),
                                        int(tokens[7]), int(tokens[8]), int(tokens[9]),
                                        tokens[10]])
                elif sec == 'Masses':
                    sectionData.append([int(tokens[0]), float(tokens[1])])
                else:
                    sectionData.append([int(_) for _ in tokens])

            f.close()
        data[sec] = sectionData
    return data

# ========================================================================================


def write_lammps_input(filename='lammps.lmp', dictData={}):
    """
    This function writes data as lammps input file in full atomic style.
    It includes box, masses, atoms, bonds, angles, dihedrals, impropoers, and types.
    Its input data format is a dictionary.

    Exmaple:

    write_lammps_input('out.lmp', dictData=data, header_types=[9,2,1,0,0])
    """
    f = open(filename, 'w')
    # f.write('LAMMPS data file. CGCMM style. atom_style full generated by VMD/TopoTools v1.5\n')
    f.write('LAMMPS data file generated by ATL %s\n'%datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

    # headers
    for h in 'Atoms Bonds Angles Dihedrals Impropers'.split():
        for k in dictData.keys():
            if h == k:
                f.write('%d %s\n' % (len(dictData[k]), k.lower()))
                # types of Atoms, Bonds, Angles, etc

    types_num = ['atom types', 'bond types', 'angle types', 'dihedral types', 'improper types']
    for i, keyword in zip(range(len(types_num)), types_num):
        f.write('%d %s\n' % (dictData['Types'][i], keyword))

    # boxsize
    for k in dictData.keys():
        if k == 'Box':
            for i, lohi in zip(range(3), ['xlo xhi', 'ylo yhi', 'zlo zhi']):
                f.write('%f %f %s\n' % (dictData[k][i][0], dictData[k][i][1], lohi))
            if len(dictData[k])==4:
                f.write('%f %f %f %s\n' % (dictData[k][3][0], dictData[k][3][1], dictData[k][3][2], "xy xz yz"))

    # sections
    f.write('\n\n')
    for h in 'Masses Atoms Bonds Angles Dihedrals Impropers'.split():
        for k in dictData.keys():
            if h == k:
                if len(dictData[k]):
                    f.write('%s\n\n'%k)
                for x in dictData[k]:
                    if k == 'Atoms':
                        f.write('%d %d %d %f %f %f %f %d %d %d #%s\n' % (
                        x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10]))
                    elif k == 'Bonds':
                        f.write('%d %d %d %d\n' % (x[0], x[1], x[2], x[3]))
                    elif k == 'Angles':
                        f.write('%d %d %d %d %d\n' % (x[0], x[1], x[2], x[3], x[4]))
                    elif k == 'Dihedrals':
                        f.write('%d %d %d %d %d %d\n' % (x[0], x[1], x[2], x[3], x[4], x[5]))
                    elif k == 'Impropers':
                        f.write('%d %d %d %d %d %d\n' % (x[0], x[1], x[2], x[3], x[4], x[5]))
                    elif k == 'Masses':
                        f.write('%d %f\n' % (x[0], x[1]))
                    else:
                        f.write('%s\n' % " ".join([str(_) for _ in x]))
                f.write('\n\n')
    f.close()
