jest.mock("../../entities/Patient", () => ({ Patient: class Patient {} }));
jest.mock("../../entities/Doctor", () => ({ Doctor: class Doctor {} }));
jest.mock("../../entities/Specialty", () => ({ Specialty: class Specialty {} }));
jest.mock("../../entities/Appointment", () => ({
  Appointment: class Appointment {},
  AppointmentStatus: {
    SCHEDULED: "SCHEDULED",
    CONFIRMED: "CONFIRMED",
    CANCELLED: "CANCELLED",
    COMPLETED: "COMPLETED",
  },
}));

jest.mock("../../config/database", () => ({
  AppDataSource: { getRepository: jest.fn() },
}));

jest.mock("../../repositories/SpecialtyRepository");

import { SpecialtyService } from "../../services/SpecialtyService";
import { SpecialtyRepository } from "../../repositories/SpecialtyRepository";
import { CreateSpecialtyDTO } from "../../dtos/SpecialtyDTO";
import { Specialty } from "../../entities/Specialty";

type SpecialtyMock = {
  id: string;
  name: string;
  description: string;
  doctors: Specialty["doctors"];
  createdAt: Date;
  updatedAt: Date;
};

describe("SpecialtyService", () => {
  let service: SpecialtyService;
  let mockRepo: jest.Mocked<SpecialtyRepository>;

  const mockSpecialty: SpecialtyMock = {
    id: "uuid-specialty-1",
    name: "Cardiologia",
    description: "Especialidade do coração",
    doctors: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    service = new SpecialtyService();
    mockRepo = (service as unknown as { specialtyRepository: SpecialtyRepository }).specialtyRepository as jest.Mocked<SpecialtyRepository>;
  });

  // ─── findAll ──────────────────────────────────────────────
  describe("findAll", () => {
    it("deve retornar lista de especialidades", async () => {
      mockRepo.findAll.mockResolvedValue([mockSpecialty as unknown as Specialty]);
      const result = await service.findAll();
      expect(result).toEqual([mockSpecialty]);
      expect(mockRepo.findAll).toHaveBeenCalledTimes(1);
    });

    it("deve retornar lista vazia", async () => {
      mockRepo.findAll.mockResolvedValue([]);
      const result = await service.findAll();
      expect(result).toEqual([]);
    });
  });

  // ─── findById ─────────────────────────────────────────────
  describe("findById", () => {
    it("deve retornar a especialidade quando encontrada", async () => {
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      const result = await service.findById("uuid-specialty-1");
      expect(result).toEqual(mockSpecialty);
      expect(mockRepo.findById).toHaveBeenCalledWith("uuid-specialty-1");
    });

    it("deve lançar AppError 404 quando especialidade não existe", async () => {
      mockRepo.findById.mockResolvedValue(null);
      await expect(service.findById("inexistente")).rejects.toMatchObject({
        statusCode: 404,
        message: "Especialidade não encontrada",
      });
    });
  });

  // ─── create ───────────────────────────────────────────────
  describe("create", () => {
    const createDTO: CreateSpecialtyDTO = {
      name: "Dermatologia",
      description: "Especialidade da pele",
    };

    it("deve criar uma especialidade com sucesso", async () => {
      mockRepo.findByName.mockResolvedValue(null);
      const newSpecialty: SpecialtyMock = { ...mockSpecialty, name: "Dermatologia", description: "Especialidade da pele" };
      mockRepo.create.mockResolvedValue(newSpecialty);
      const result = await service.create(createDTO);
      expect(result.name).toBe("Dermatologia");
      expect(mockRepo.findByName).toHaveBeenCalledWith("Dermatologia");
      expect(mockRepo.create).toHaveBeenCalledTimes(1);
    });

    it("deve criar especialidade sem descrição", async () => {
      mockRepo.findByName.mockResolvedValue(null);
      const newSpecialty: SpecialtyMock = { ...mockSpecialty, name: "Ortopedia", description: null as unknown as string };
      mockRepo.create.mockResolvedValue(newSpecialty);
      const result = await service.create({ name: "Ortopedia" });
      expect(result.name).toBe("Ortopedia");
      expect(mockRepo.create).toHaveBeenCalledWith({ name: "Ortopedia", description: null });
    });

    it("deve lançar AppError 409 quando nome já existe", async () => {
      mockRepo.findByName.mockResolvedValue(mockSpecialty);
      await expect(service.create(createDTO)).rejects.toMatchObject({
        statusCode: 409,
        message: "Já existe uma especialidade com este nome",
      });
      expect(mockRepo.create).not.toHaveBeenCalled();
    });
  });

  // ─── update ───────────────────────────────────────────────
  describe("update", () => {
    it("deve atualizar a especialidade com sucesso", async () => {
      const updatedSpecialty: SpecialtyMock = { ...mockSpecialty, name: "Cardiologia Intervencionista" };
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      mockRepo.findByName.mockResolvedValue(null);
      mockRepo.update.mockResolvedValue(updatedSpecialty);
      const result = await service.update("uuid-specialty-1", { name: "Cardiologia Intervencionista" });
      expect(result.name).toBe("Cardiologia Intervencionista");
    });

    it("deve permitir manter o mesmo nome sem erro de duplicidade", async () => {
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      mockRepo.update.mockResolvedValue(mockSpecialty);
      await service.update("uuid-specialty-1", { name: "Cardiologia" });
      expect(mockRepo.findByName).not.toHaveBeenCalled();
    });

    it("deve lançar AppError 409 quando novo nome já pertence a outra especialidade", async () => {
      const outraSpecialty: SpecialtyMock = { ...mockSpecialty, id: "uuid-outro", name: "Neurologia" };
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      mockRepo.findByName.mockResolvedValue(outraSpecialty);
      await expect(
        service.update("uuid-specialty-1", { name: "Neurologia" })
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it("deve lançar AppError 404 quando especialidade não existe", async () => {
      mockRepo.findById.mockResolvedValue(null);
      await expect(service.update("inexistente", { name: "Teste" })).rejects.toMatchObject({ statusCode: 404 });
    });

    it("deve lançar AppError 500 quando update retorna null", async () => {
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      mockRepo.update.mockResolvedValue(null);
      await expect(service.update("uuid-specialty-1", { name: "Nova" })).rejects.toMatchObject({ statusCode: 500 });
    });

    it("deve atualizar apenas a descrição", async () => {
      const updatedSpecialty: SpecialtyMock = { ...mockSpecialty, description: "Nova descrição" };
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      mockRepo.update.mockResolvedValue(updatedSpecialty);
      const result = await service.update("uuid-specialty-1", { description: "Nova descrição" });
      expect(result.description).toBe("Nova descrição");
      expect(mockRepo.findByName).not.toHaveBeenCalled();
    });
  });

  // ─── delete ───────────────────────────────────────────────
  describe("delete", () => {
    it("deve deletar a especialidade com sucesso", async () => {
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      mockRepo.delete.mockResolvedValue(true);
      await expect(service.delete("uuid-specialty-1")).resolves.toBeUndefined();
      expect(mockRepo.delete).toHaveBeenCalledWith("uuid-specialty-1");
    });

    it("deve lançar AppError 404 quando especialidade não existe", async () => {
      mockRepo.findById.mockResolvedValue(null);
      await expect(service.delete("inexistente")).rejects.toMatchObject({ statusCode: 404 });
    });

    it("deve lançar AppError 500 quando delete falha", async () => {
      mockRepo.findById.mockResolvedValue(mockSpecialty);
      mockRepo.delete.mockResolvedValue(false);
      await expect(service.delete("uuid-specialty-1")).rejects.toMatchObject({ statusCode: 500 });
    });
  });
});
